-- DoF/Locale/enUS/Effects.lua
-- Status effect names and descriptions (Data/Effects.lua).
--
-- Stat terminology used across the addon:
--   Стойкость = Fortitude, Сноровка = Reflex, Воля = Will,
--   Сила = Strength, Ловкость = Dexterity, Интеллект = Intelligence, Дух = Spirit.

local ADDON_NAME, DoF = ...

DoF.Locale:Register("enUS", {
    -- ══════════ DoT ══════════
    ["effects.bleeding.name"] = "Damage over Time",
    ["effects.bleeding.desc"] = "Damage each round",
    ["effects.dot_master.name"] = "Damage over Time",
    ["effects.dot_master.desc"] = "Damage from the NPC each round",

    -- ══════════ Debuffs (GM -> player) ══════════
    ["effects.stun.name"] = "Stun",
    ["effects.stun.desc"] = "Skips the turn",

    -- ══════════ NPC defensive stat reduction ══════════
    ["effects.weakness_fortitude.name"] = "Weakness (Fortitude)",
    ["effects.weakness_fortitude.desc"] = "Lowers NPC Fortitude",
    ["effects.weakness_reflex.name"] = "Weakness (Reflex)",
    ["effects.weakness_reflex.desc"] = "Lowers NPC Reflex",
    ["effects.weakness_will.name"] = "Weakness (Will)",
    ["effects.weakness_will.desc"] = "Lowers NPC Will",

    -- ══════════ Player weakening ══════════
    ["effects.weakness_damage.name"] = "Weakness (Damage)",
    ["effects.weakness_damage.desc"] = "Lowers the player's outgoing damage",
    ["effects.weakness_healing.name"] = "Weakness (Healing)",
    ["effects.weakness_healing.desc"] = "Lowers the player's healing",

    -- ══════════ Player defensive stat vulnerability ══════════
    ["effects.vulnerability_fortitude.name"] = "Vulnerability (Fortitude)",
    ["effects.vulnerability_fortitude.desc"] = "Lowers player Fortitude",
    ["effects.vulnerability_reflex.name"] = "Vulnerability (Reflex)",
    ["effects.vulnerability_reflex.desc"] = "Lowers player Reflex",
    ["effects.vulnerability_will.name"] = "Vulnerability (Will)",
    ["effects.vulnerability_will.desc"] = "Lowers player Will",

    -- ══════════ Empower ══════════
    ["effects.empower_strength.name"] = "Empower (Strength)",
    ["effects.empower_strength.desc"] = "+2 Strength (AoE: +4)",
    ["effects.empower_dexterity.name"] = "Empower (Dexterity)",
    ["effects.empower_dexterity.desc"] = "+2 Dexterity (AoE: +4)",
    ["effects.empower_intelligence.name"] = "Empower (Intelligence)",
    ["effects.empower_intelligence.desc"] = "+2 Intelligence (AoE: +4)",
    ["effects.empower_spirit.name"] = "Empower (Spirit)",
    ["effects.empower_spirit.desc"] = "+2 Spirit (AoE: +4)",
    ["effects.empower_damage.name"] = "Empower (Damage)",
    ["effects.empower_damage.desc"] = "+1 Damage (AoE: +2)",
    ["effects.empower_healing.name"] = "Empower (Healing)",
    ["effects.empower_healing.desc"] = "+1 Healing (AoE: +2, ignores the 50% cap)",

    -- ══════════ Fortify ══════════
    ["effects.fortify_fortitude.name"] = "Fortify (Fortitude)",
    ["effects.fortify_fortitude.desc"] = "+2 Fortitude (AoE: +4)",
    ["effects.fortify_reflex.name"] = "Fortify (Reflex)",
    ["effects.fortify_reflex.desc"] = "+2 Reflex (AoE: +4)",
    ["effects.fortify_will.name"] = "Fortify (Will)",
    ["effects.fortify_will.desc"] = "+2 Will (AoE: +4)",
    ["effects.fortify_hp.name"] = "Fortify (HP)",
    ["effects.fortify_hp.desc"] = "+2 max HP (AoE: +4)",

    -- ══════════ Tank ══════════
    ["effects.tank_fort_streak.name"] = "Steadfast Defense (Fortitude)",
    ["effects.tank_fort_streak.desc"] = "Fortitude bonus for a streak of successful defenses",
    ["effects.tank_reflex_streak.name"] = "Steadfast Defense (Reflex)",
    ["effects.tank_reflex_streak.desc"] = "Reflex bonus for a streak of successful defenses",
    ["effects.tank_will_streak.name"] = "Steadfast Defense (Will)",
    ["effects.tank_will_streak.desc"] = "Will bonus for a streak of successful defenses",
    ["effects.tank_shred_fortitude.name"] = "Shred (Fortitude)",
    ["effects.tank_shred_fortitude.desc"] = "Lowers NPC Fortitude (-2 per stack, 3 stacks max)",
    ["effects.tank_shred_reflex.name"] = "Shred (Reflex)",
    ["effects.tank_shred_reflex.desc"] = "Lowers NPC Reflex (-2 per stack, 3 stacks max)",
    ["effects.tank_redirect.name"] = "Damage Redirect",
    ["effects.tank_redirect.desc"] = "The NPC's next attack on the target is redirected to the tank",
    ["effects.tank_taunt.name"] = "Taunt",
    ["effects.tank_taunt.desc"] = "The NPC must attack the tank",

    -- ══════════ Healing ══════════
    ["effects.healing_fatigue.name"] = "Healing Fatigue",
    ["effects.healing_fatigue.desc"] = "Raises the threshold for a successful heal (+2 per stack)",
    ["effects.shield_exhaustion.name"] = "Shield Exhaustion",
    ["effects.shield_exhaustion.desc"] = "The shield broke recently. A new shield cannot be applied.",

    -- ══════════ Cooldowns ══════════
    ["effects.cooldown_tank_redirect.name"] = "Cooldown (Redirect)",
    ["effects.cooldown_tank_redirect.desc"] = "Damage Redirect is recharging",
    ["effects.cooldown_tank_taunt.name"] = "Cooldown (Taunt)",
    ["effects.cooldown_tank_taunt.desc"] = "Taunt is recharging",
    ["effects.cooldown_tank_taunt_aoe.name"] = "Cooldown (Mass Taunt)",
    ["effects.cooldown_tank_taunt_aoe.desc"] = "Mass Taunt is recharging",
    ["effects.cooldown_special_action.name"] = "Cooldown (Special)",
    ["effects.cooldown_special_action.desc"] = "The special action is recharging",
    ["effects.cooldown_aoe.name"] = "Cooldown (AoE)",
    ["effects.cooldown_aoe.desc"] = "AoE attack and healing are recharging",
    ["effects.cooldown_shield.name"] = "Cooldown (Shield)",
    ["effects.cooldown_shield.desc"] = "Shield is recharging",
    ["effects.cooldown_aoe_shield.name"] = "Cooldown (AoE Shield)",
    ["effects.cooldown_aoe_shield.desc"] = "AoE Shield is recharging",

    -- ══════════════════════════════════════════════════════
    -- APPLY AND REMOVE MESSAGES (Data/Effects.lua)
    -- ══════════════════════════════════════════════════════
    ["effects.msg.applies"] = "%s applies %s to %s",
    ["effects.msg.applies_aoe"] = "%s [AoE] applies %s to %s",
    ["effects.msg.applied_aoe"] = "[AoE] %s applied to %s",
    ["effects.msg.applies_weakness"] = "%s applies |cFF%s%s|r (-%d) to %s for %d rounds",
    ["effects.msg.stacked"] = "%s strengthened by %s (stacks: %d)",
    ["effects.msg.starts_on"] = "%s takes effect on %s",
    ["effects.msg.removed_from"] = "%s removed from %s",
    ["effects.msg.already_applied_here"] = "You have already applied %s to this target",
    ["effects.msg.already_applied_on"] = "You have already applied %s to %s",
    ["effects.msg.max_stacks"] = "%s — %s stacks maximum!",
    ["effects.msg.dot_damage_hp"] = "%s takes %d damage from %s. HP: %d/%d",
    ["effects.msg.dot_damage"] = "%s takes %d damage from %s",
    ["effects.msg.hot_heal"] = "%s restores %d HP",
    ["effects.msg.stun_over"] = "|cFFFFFF00%s|r is no longer stunned!",
    ["effects.msg.debuff_removed"] = "Debuff removed from %s",
    ["effects.msg.debuff_removed_log"] = "%s removes a debuff from %s",
    ["effects.msg.buff_removed"] = "Buff removed from %s",
    ["effects.msg.no_debuffs"] = "No debuffs to remove",
    ["effects.msg.no_buffs"] = "No buffs to remove",
    ["effects.msg.npc_fallback"] = "NPC",

    -- Denial reasons (returned as the second value from the access check)
    ["effects.deny.unknown"] = "Unknown effect",
    ["effects.deny.master_only"] = "Only the GM can use this effect",
    ["effects.deny.cooldown"] = "Cooldown: %s %s",
    ["effects.deny.not_enough_energy"] = "Not enough energy (need %s)",
    ["effects.deny.role_required"] = "Role required: %s",

    ["effects.action.apply"] = "Applying an effect",
})
