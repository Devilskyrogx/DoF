-- DoF/Locale/enUS/Combat.lua
-- Combat messages: combat log, chat, roll results.
--
-- IMPORTANT: these strings travel over the wire already rendered
-- (Sync/Core.lua:BroadcastCombatLog takes finished text). Until the protocol
-- moves to "key + arguments", the receiver sees the sender's language.

local ADDON_NAME, DoF = ...

DoF.Locale:Register("enUS", {
    -- ══════════════════════════════════════════════════════
    -- ROLL OUTCOMES
    -- Short words substituted into the result lines below.
    -- ══════════════════════════════════════════════════════
    ["combat.result.crit_fail"] = "critical fail",
    ["combat.result.crit_success"] = "critical success",
    ["combat.result.dodge"] = "dodged",
    ["combat.result.success"] = "success",
    ["combat.result.fail"] = "failure",
    ["combat.result.fail_fatigue"] = "failure (fatigue)",
    ["combat.result.reflected"] = "reflected",
    ["combat.result.crit_fail_excl"] = "critical fail!",
    ["combat.result.crit_success_excl"] = "critical success!",
    ["combat.result.success_excl"] = "success!",
    ["combat.result.failure"] = "failure",

    -- ══════════════════════════════════════════════════════
    -- ACTION NAMES
    -- Substituted into the "not your turn" and "not enough energy" checks.
    -- ══════════════════════════════════════════════════════
    ["combat.action.attack"] = "Attack",
    ["combat.action.special"] = "Special action",
    ["combat.action.heal"] = "Heal",
    ["combat.action.shield"] = "Shield",
    ["combat.action.remove_wound"] = "Wound removal",
    ["combat.action.dispel"] = "Dispel",
    ["combat.action.purge"] = "Purge",
    ["combat.action.restore_energy"] = "Energy restore",

    -- ══════════════════════════════════════════════════════
    -- ROLL AND RESULT LINES
    -- ══════════════════════════════════════════════════════
    ["combat.uses"] = "%s uses %s against %s.",
    ["combat.roll_result"] = "Result: %s (%d+%d) %s %d - %s",
    ["combat.roll_result_simple"] = "Result: %s (%d+%d)",
    ["combat.roll_line"] = "%s roll: %s (%d+%d) %s %d - %s",
    ["combat.roll_short"] = "Roll: %s (%d+%d) %s %d - %s",
    ["combat.roll_short_no_threshold"] = "Roll: %s (%d+%d) - %s",
    ["combat.reflected_damage"] = " |cFF66CCFFReflected damage: %s|r",
    ["combat.damage_suffix"] = " Damage: %s",
    ["combat.heal_suffix"] = " Healing: %s",
    ["combat.check_line"] = "%s makes a %s check.",

    -- ══════════════════════════════════════════════════════
    -- DAMAGE, DEATH, REACTIVE EFFECTS
    -- ══════════════════════════════════════════════════════
    ["combat.target_dead_msg"] = "%s — target is dead!",
    ["combat.takes_damage"] = "%s takes %s damage! HP: %s",
    ["combat.poisoned_instant"] = "%s is poisoned by %s! Instant damage: |cFFFF0000%d|r",
    ["combat.poisoned"] = "%s is poisoned by %s! (damage %d, %d rnd)",
    ["combat.poison_log"] = "Poison %s → %s: -%d HP",
    ["combat.thorns_damage"] = "|cFFFF8800Thorns|r of %s deal |cFFFF0000%d|r damage to %s!",
    ["combat.thorns_log"] = "Thorns %s → %s: -%d HP",
    ["combat.thorns_trigger"] = "|cFFFF8800Thorns|r of %s trigger! Defend yourself!",
    ["combat.berserk"] = "|cFFFF0000Berserk!|r %s counterattacks in a rage! Defend yourself!",
    ["combat.counterattack"] = "|cFFFF6666Counterattack!|r %s strikes back! Defend yourself!",

    -- ══════════════════════════════════════════════════════
    -- CRIT BONUSES
    -- ══════════════════════════════════════════════════════
    ["combat.crit_bonus"] = "%s picks a crit bonus: %s",
    ["combat.crit_bonus_target"] = "%s picks a crit bonus: %s %s",
    ["combat.crit_bonus_damage"] = "%s picks a crit bonus: %s (damage %s -> %s)",
    ["combat.bonus_damage_label"] = "+%s damage",
    ["combat.bonus_energy"] = "+1 energy",
    ["combat.bonus_full_heal"] = "Full heal",
    ["combat.bonus_shield_3"] = "+3 shield",
    ["combat.bonus_shield_1"] = "Shield (1 hit)",

    -- ══════════════════════════════════════════════════════
    -- SPECIAL ACTION
    -- ══════════════════════════════════════════════════════
    ["combat.special_performs"] = "%s performs: %s (%s) - %s",
    ["combat.special_approved_by_gm"] = "approved by the GM",
    ["combat.special_crit_fail_line"] = "%s attempts: %s (%s). Result: %s (%d+%d) - %s",
    ["combat.special_success_line"] = "%s performs: %s (%s). Result: %s (%d+%d) >= %d - %s",
    ["combat.special_fail_line"] = "%s attempts: %s (%s). Result: %s (%d+%d) < %d - %s",
    ["combat.special_damage_log"] = "%s [Special] -> %s: Damage %s",
    ["combat.special_done"] = "Special action (%s) complete! Targets: %s",
    ["combat.special_cancelled"] = "Special action cancelled!",
    ["combat.targets_left"] = "Targets left: %s",

    -- Target selection hints
    ["combat.choose_n_buff_targets"] = "Choose %s targets for the buff.",
    ["combat.choose_buff_target"] = "Choose a target for the buff and press apply.",
    ["combat.choose_npc_target"] = "Choose an NPC target to attack.",
    ["combat.choose_n_npc_targets"] = "Choose %s NPC targets to attack.",
    ["combat.choose_wound_target"] = "Choose a player to remove a wound from.",
    ["combat.choose_dispel_target"] = "Choose a player to dispel.",
    ["combat.choose_purge_target"] = "Choose an NPC target to purge.",

    -- ══════════════════════════════════════════════════════
    -- BUFFS, WOUNDS, DISPEL, PURGE
    -- ══════════════════════════════════════════════════════
    ["combat.buff_applied"] = "Buff %s applied to %s",
    ["combat.buff_applied_log"] = "%s applies %s to %s (special action)",
    ["combat.no_wounds_target"] = "%s has no wounds to remove.",
    ["combat.no_wounds_self"] = "You have no wounds.",
    ["combat.wound_removed_from"] = "Wound removed from %s",
    ["combat.wound_removed_name"] = "Wound removed from %s!",
    ["combat.wound_removed_success"] = "Wound removed successfully!",
    ["combat.wound_removed_log"] = "%s removes a wound from %s (special action)",
    ["combat.tries_remove_wound"] = "%s attempts to remove a wound from %s.",
    ["combat.no_debuffs_to_remove"] = "The target has no debuffs to remove.",
    ["combat.tries_dispel"] = "%s attempts to remove a debuff from %s.",
    ["combat.dispel_log"] = "%s removes %s from %s!",
    ["combat.no_buffs_to_remove"] = "The target has no buffs to remove.",
    ["combat.tries_purge"] = "%s attempts to remove a buff from %s.",
    ["combat.purge_passive_log"] = "%s removes the passive %s from %s!",
    ["combat.purge_log"] = "%s removes a buff from %s (special action)",

    -- ══════════════════════════════════════════════════════
    -- HEALING, ENERGY, SHIELD
    -- ══════════════════════════════════════════════════════
    ["combat.heals"] = "%s heals %s (%s).",
    ["combat.you_healed"] = "You restored %s HP! (%s/%s)",
    ["combat.target_healed"] = "%s restored %s HP! (%s/%s)",
    ["combat.target_healed_short"] = "%s restored %s HP!",
    ["combat.full_heal_hp"] = "Full heal! HP: %s/%s",
    ["combat.full_heal_target"] = "Full heal on %s!",
    -- %s — the plural form of "stack", picked by DoF.Locale:Plural
    ["combat.healing_fatigue"] = "Healing fatigue: %d %s. Heal threshold: %s",
    ["combat.stacks_one"] = "stack",
    ["combat.stacks_few"] = "stacks",
    ["combat.stacks_many"] = "stacks",
    ["combat.npc_fallback"] = "NPC",
    ["combat.energy_restored_log"] = "%s restores 1 energy for %s",
    ["combat.shield_recently_broken_warn"] = "%s's shield was recently broken!",
    ["combat.shield_already_active"] = "A shield is already active!",
    ["combat.shield_already_active_on"] = "A shield is already active on %s!",
    ["combat.shield_applied_log"] = "%s casts a shield on %s. The next damage will be fully absorbed.",
    ["combat.shield_applied_you"] = "You cast a shield on %s. The next damage will be fully absorbed.",

    -- ══════════════════════════════════════════════════════
    -- DEFENSE, TANK, TAUNT (Combat/Defense.lua)
    -- ══════════════════════════════════════════════════════
    ["combat.result.crit_defense"] = "critical defense",
    ["combat.action.taunt"] = "Taunt",
    ["combat.action.mass_taunt"] = "Mass Taunt",
    ["combat.action.redirect"] = "Damage Redirect",

    ["combat.label.counterattack"] = "Counterattack",
    ["combat.label.taunt"] = "Taunt",
    ["combat.label.mass_taunt_acc"] = "Mass Taunt",
    ["combat.label.redirect"] = "Damage Redirect",
    ["combat.label.tank_hp"] = "+2 HP",
    ["combat.label.hybrid"] = "Hybrid",
    ["combat.label.gm"] = "GM",
    ["combat.label.gained"] = "gained",
    ["combat.label.lost"] = "lost",
    ["combat.label.hp_added"] = "Added",
    ["combat.label.hp_removed"] = "Removed",
    ["combat.label.auto_fail"] = "auto-fail",

    ["combat.def.attacks"] = "%s attacks %s.",
    ["combat.def.defends_line"] = "%s defends with %s: %s (%d+%d) %s %d - %s",
    ["combat.def.debuff_suffix"] = "%s for %s rnd",
    ["combat.def.no_defense_line"] = "%s failed to defend in time - %s!",
    ["combat.def.time_up_damage"] = "Time is up! Damage taken: %s",
    ["combat.def.crit_defense_bonus"] = "%s picks a defense crit: %s",
    ["combat.def.crit_defense_bonus_damage"] = "%s picks a defense crit: %s (damage: %s)",
    ["combat.def.counter_damage_taken"] = "%s takes %s counterattack damage! HP: %s",
    ["combat.def.counter_prompt"] = "Counterattack! Choose an NPC target and press |cFFFF6666Strike|r. Damage: %s",
    ["combat.def.counter_timeout"] = "The counterattack window expired!",
    ["combat.def.counter_log"] = "%s [Counterattack] -> %s: %s HP: %s",
    -- %% — escaped percent: the string goes through string.format
    ["combat.def.fighter_counter"] = "Fighter: %s! (15%% chance)",

    ["combat.def.tank_streak_broken"] = "Tank: defense streak broken! The %s buff was removed.",
    ["combat.def.tank_streak_max"] = "Tank: Steadfast Defense (%s) is at its maximum level (3)",
    ["combat.def.tank_streak"] = "Tank: defense streak! %s (3 rounds)",
    ["combat.def.tank_streak_label"] = "Steadfast Defense (%s) +%s",
    ["combat.def.tank_streak_log"] = "%s gains the Steadfast Defense (%s) +%s buff",
    ["combat.def.shred_max_both"] = "Tank: shredding %s — maximum stacks reached on both stats!",
    ["combat.def.shred_max_stat"] = "Tank: maximum shred stacks (%s) already reached!",
    ["combat.def.shred_applied"] = "Tank: defense shred! %s (%s/%s stacks)",
    ["combat.def.shred_label"] = "%s -%s",
    ["combat.def.shred_log"] = "%s shreds %s's defense: %s",
    ["combat.def.tank_choose_ally"] = "Tank: choose an ally for the %s buff!",
    ["combat.def.tank_hp_buff_applied"] = "Tank: %s gains %s (3 rounds)",
    ["combat.def.tank_hp_buff_log"] = "%s fortifies %s (+2 HP)",

    ["combat.def.gm_hp_log"] = "%s %s %d HP (GM). HP: %d/%d",
    ["combat.def.healed_log"] = "%s was healed by %s. HP: %d/%d",
    ["combat.def.hp_change_msg"] = "%s %s HP to player %s",
    ["combat.def.hp_change_log"] = "Changed player HP '%s': %+d",
    ["combat.def.shield_already"] = "A shield is already active! The new shield was not applied.",
    ["combat.def.shield_broken"] = "The shield was recently broken! The new shield was not applied.",
    ["combat.def.not_defended_yet"] = "%s has not defended against the previous attack yet!",
    ["combat.def.npc_attack_log"] = "%s attacks '%s': damage %s, threshold %d, defense: %s",
    ["combat.def.debuff_log_suffix"] = ", debuff: %s",

    ["combat.def.taunt_applied"] = "Tank: %s on %s!",
    ["combat.def.taunt_log"] = "%s taunts %s! The NPC must attack the tank (%d rnd)",
    ["combat.def.mass_taunt_prompt"] = "Tank: %s! Choose an NPC (left: %s)",
    ["combat.def.taunt_progress"] = "Taunt: %s (left: %s)",
    ["combat.def.mass_taunt_log"] = "%s uses %s! (%d targets)",
    ["combat.def.mass_taunt_cancelled"] = "Mass Taunt cancelled.",
    ["combat.def.redirect_log"] = "%s redirects the next attack for %s!",
    ["combat.def.redirect_absorb_log"] = "%s redirects damage for %s!",

    -- ══════════════════════════════════════════════════════
    -- AoE MODES (Combat/AoE.lua)
    -- ══════════════════════════════════════════════════════
    ["combat.action.aoe_attack"] = "AoE attack",
    ["combat.action.aoe_heal"] = "AoE heal",
    ["combat.action.aoe_buff"] = "AoE buff",
    ["combat.action.aoe_shield"] = "AoE shield",

    ["combat.result.crit_short"] = "crit!",
    ["combat.result.hit_short"] = "hit!",

    ["combat.aoe.activates"] = "%s activates AoE %s!",
    ["combat.aoe.activates_heal"] = "%s activates AoE healing!",
    ["combat.aoe.activates_shield"] = "%s activates AoE shield! Targets: %s",
    ["combat.aoe.roll_crit"] = "Roll: %s - %s! Targets: %s",
    ["combat.aoe.roll_success"] = "Roll: %s - %s Targets: %s",
    ["combat.aoe.targets_line"] = "Targets: %s",
    ["combat.aoe.attack_log"] = "%s [AoE %s] -> %s: %s Damage: %s",
    ["combat.aoe.heal_log"] = "%s [AoE Healing] -> %s: %s Healing: %s",

    ["combat.aoe.mode_active"] = "AoE mode active! Choose %s targets.",
    ["combat.aoe.heal_active"] = "AoE healing active! Choose %s allies.",
    ["combat.aoe.buff_choose"] = "Choose %s allies for %s",
    ["combat.aoe.shield_active"] = "AoE shield active! Choose %s targets.",

    ["combat.aoe.hits_left"] = "Strikes left: %s",
    ["combat.aoe.heals_left"] = "Heals left: %s",
    ["combat.aoe.buffs_left"] = "Buffs left: %s",
    ["combat.aoe.shields_left"] = "Shields left: %s",

    ["combat.aoe.attack_done"] = "AoE attack complete! Targets hit: %s",
    ["combat.aoe.heal_done"] = "AoE healing complete! Allies healed: %s",
    ["combat.aoe.buff_done"] = "AoE buff complete! Allies buffed: %s",
    ["combat.aoe.shield_done"] = "AoE shield complete! Targets shielded: %s",

    ["combat.aoe.attack_cancelled"] = "AoE attack cancelled!",
    ["combat.aoe.heal_cancelled"] = "AoE healing cancelled!",
    ["combat.aoe.buff_cancelled"] = "AoE buff cancelled!",
    ["combat.aoe.shield_cancelled"] = "AoE shield cancelled!",

    ["combat.aoe.shield_applied"] = "Shield applied to %s",
    ["combat.aoe.shield_already_here"] = "A shield is already active! Choose another target.",
    ["combat.aoe.shield_already_on"] = "A shield is already active on %s! Choose another target.",

    -- ══════════════════════════════════════════════════════
    -- TURN-BASED COMBAT (Combat/TurnSystem*.lua)
    -- ══════════════════════════════════════════════════════
    ["combat.turn.round_header"] = "|cFFFFD700══ Round %s ══|r",
    ["combat.turn.stun_starts"] = "%s takes effect on %s",
    ["combat.turn.all_incapacitated"] = "All participants are incapacitated — moving to the NPC phase",
    ["combat.turn.all_stunned"] = "All participants are stunned — moving to the NPC phase",
    ["combat.turn.skip_critical"] = "%s skips the turn (critical wound)",
    ["combat.turn.skip_stun"] = "%s skips the turn (stun, %s left)",
    ["combat.turn.you_unconscious"] = "You are unconscious — turn skipped. Await the GM's decision.",
    -- %s — the plural form of "round", picked by DoF.Locale:Rounds
    ["combat.turn.you_stunned"] = "You are stunned and skip the turn! %d %s left",
    ["combat.turn.fatigue_cleared"] = "Healing fatigue fully cleared!",
    ["combat.turn.fatigue_reduced"] = "Healing fatigue reduced to %d %s. Threshold: %s",
    ["combat.turn.state_synced"] = "Combat state synchronized: round %s, phase: %s",
    ["combat.turn.unknown_player"] = "unknown player",
    ["combat.turn.extra_turn_self"] = "|cFFFFD700You granted yourself an extra turn.|r Take an action.",
    ["combat.turn.extra_turn_you"] = "|cFFFFD700You were granted an extra turn!|r Take an action.",
    ["combat.turn.extra_turn_given"] = "|cFFFFD700An extra turn|r was granted to %s.",
    ["combat.turn.extra_turn_log"] = "An extra turn was granted to %s.",

    -- ══════════════════════════════════════════════════════
    -- SYNC SECURITY (Sync/Security.lua)
    -- ══════════════════════════════════════════════════════
    ["combat.sec.blocked"] = "Blocked: %s from %s (%s)",
    ["combat.sec.not_in_group"] = "not in the group",
    ["combat.sec.not_master"] = "not the GM",
    ["combat.sec.confirm"] = "|cFFFFFFFFConfirm|r",
    ["combat.sec.decline"] = "|cFFFFFFFFDecline|r",
    ["combat.sec.from"] = "From: |cFFA06AF1%s|r",
    ["combat.sec.declined"] = "Action declined",
    ["combat.sec.timeout"] = "The confirmation window expired — action declined",

    -- ══════════════════════════════════════════════════════
    -- SYNCHRONIZATION (Sync/Core.lua, Sync/Handlers.lua)
    -- ══════════════════════════════════════════════════════
    ["combat.sync.no_npc_data"] = "DoF: NPC data was not received — press \"Refresh\" on the action bar",
    ["combat.sync.timeout_retry"] = "NPC data timed out, retrying (%s/%s)...",
    ["combat.sync.not_in_group"] = "You are not in a group — there is nobody to get data from.",
    ["combat.sync.wait_before_retry"] = "Wait %ss before requesting again...",
    ["combat.sync.requested_target"] = "Requested data for the current target...",
    ["combat.sync.requested_all"] = "Requested data for all NPCs from the GM...",
    ["combat.sync.you_are_master"] = "You are now the session GM",
    ["combat.sync.recovery_failed"] = "Could not get recovery data from any player",
    ["combat.sync.recovery_no_candidates"] = "Recovery: no candidates available",
    ["combat.sync.recovery_request"] = "Recovery request from %s (attempt %s)",
    ["combat.sync.message_too_big"] = "Sync: message %s = %s bytes (> %s). AceComm will chunk it, but check the payload.",
    ["combat.sync.turn_change_no_ack"] = "TURN_CHANGE was not acknowledged after %s attempts",
    ["combat.sync.action_done_no_ack"] = "ACTION_DONE was not acknowledged — the GM may not have received it",
    ["combat.sync.in_reliable"] = "%s (in RELIABLE)",
    ["combat.sync.master_silent"] = "The GM '%s' has been silent for %ss. They may need a /reload, or /promote a new GM.",
    ["combat.sync.master_is"] = "GM: %s",
    ["combat.sync.data_from_master"] = "Data from the GM: %s NPCs",
    ["combat.sync.data_from_group"] = "Recovered from the group: %s NPCs",
    ["combat.sync.format_unsupported"] = "FULLDATA3 format v%s is not supported — update the addon",
    ["combat.sync.hpchange_rejected"] = "HPCHANGE rejected: ver %s < %s from %s",
    ["combat.sync.no_role_chosen"] = "[DoF] Player %s has not chosen a role!",
    ["combat.sync.desync_resync"] = "NPC data is out of sync, requesting a resync...",

    -- GM actions on a player
    ["combat.sync.spec_set"] = "%s's specialization: %s",
    ["combat.sync.level_set"] = "%s's level: %s",
    ["combat.sync.spec_removed"] = "removed",
    ["combat.sync.spec_log"] = "Set spec '%s' for player '%s'",
    ["combat.sync.wound_added"] = "Wound added to player %s",
    ["combat.sync.wound_added_log"] = "Added a wound to player '%s'",
    ["combat.sync.wound_removed"] = "Wound removed from player %s",
    ["combat.sync.wound_removed_log"] = "Removed a wound from player '%s'",
    ["combat.sync.stats_reset"] = "Stats reset for player %s",
    ["combat.sync.stats_reset_log"] = "Reset stats for player '%s'",
    ["combat.sync.shield_given"] = "Shield given to player %s",
    ["combat.sync.shield_given_log"] = "Gave a shield to player '%s'",
    ["combat.sync.energy_given"] = "Gave %s to player %s",
    ["combat.sync.energy_taken"] = "Took %s from player %s",
    ["combat.sync.energy_amount"] = "%s energy",
    ["combat.sync.energy_received"] = "Received %s from %s",
    ["combat.sync.energy_removed_by_master"] = "The GM took %s",
    ["combat.sync.energy_from_healer"] = "Received %s from healer %s",

    -- Messages to the player
    ["combat.sync.special_rejected"] = "|cFFFF6666Special action rejected.|r",
    ["combat.sync.special_rejected_by_master"] = "|cFFFF6666The GM rejected your special action.|r",
    ["combat.sync.hp_changed_log"] = "%s changed health: %s → %s (%s%d)",
    ["combat.sync.full_heal_from"] = "Full heal from %s! HP: %s/%s",
    ["combat.sync.role_removal_title"] = "Role removal",
    ["combat.sync.role_removal_text"] = "%s wants to remove your |cFFA06AF1%s|r role.\n\nConfirm?",
    ["combat.sync.role_removed_by"] = "Your role was removed by GM %s",
    ["combat.sync.role_changed_by"] = "Your role was changed to %s by GM %s",
    ["combat.sync.level_raised_by"] = "Your level was raised to %s by GM %s",
    ["combat.sync.level_lowered_by"] = "Your level was lowered to %s by GM %s",
    ["combat.sync.wound_from"] = "You received a wound from %s",
    ["combat.sync.wound_removed_by"] = "%s removed a wound from you!",
    ["combat.sync.stats_reset_title"] = "Stat reset",
    ["combat.sync.stats_reset_text"] = "%s wants to |cFFFF0000RESET|r your stats!\n\n|cFFFF6666This will remove:|r\n- Your role\n- Assigned points\n\nConfirm?",
    ["combat.sync.stats_reset_by"] = "Your stats were reset by GM %s",
    ["combat.sync.shield_from_master"] = "Received a shield from the GM!",

    -- Confirmations
    ["combat.sync.confirmed"] = "%s |cFF66FF66confirmed|r: %s",
    ["combat.sync.confirmed_log"] = "%s confirmed: %s",
    ["combat.sync.declined"] = "%s |cFFFF6666declined|r: %s",
    ["combat.sync.declined_log"] = "%s declined: %s",
    ["combat.sync.no_answer"] = "%s did not answer in time: %s",
    ["combat.sync.no_answer_log"] = "%s did not answer: %s",

    -- Survival roll
    ["combat.sync.survival_line"] = "%s — survival roll (%s): %s (%d%s) against DC %d → %s",
    ["combat.sync.survival_success"] = "SUCCESS",
    ["combat.sync.survival_fail"] = "FAILURE",
    ["combat.sync.death_line"] = "%s did not survive the wound. The character dies.",
})
