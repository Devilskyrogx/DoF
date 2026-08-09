-- DoF/Locale/enUS/Passives.lua
-- Passive ability names and their parameter labels (Data/Passives.lua).
--
-- Parameter labels are keyed as passives.<passive>.field.<key> rather than by field
-- key alone: the same "value" field means different things across passives
-- (HP per round for regeneration, damage reduction for resistance).

local ADDON_NAME, DoF = ...

DoF.Locale:Register("enUS", {
    -- ─── REACTIVE ─────────────────────────────────────────
    ["passives.thorns.name"] = "Thorns",
    ["passives.thorns.desc"] = "Attacking the NPC triggers an automatic counterattack. The player defends with Fortitude or Reflex, their choice",
    ["passives.thorns.field.mode"] = "Mode",
    ["passives.thorns.field.chance"] = "Chance %",
    ["passives.thorns.field.damageMin"] = "Damage min",
    ["passives.thorns.field.damageMax"] = "Damage max",
    ["passives.thorns.field.threshold"] = "Defense threshold",
    ["passives.thorns.field.instantDamage"] = "Instant damage",

    ["passives.npc_counterattack.name"] = "Counterattack",
    ["passives.npc_counterattack.desc"] = "Chance to strike back after any attack on the NPC",
    ["passives.npc_counterattack.field.chance"] = "Chance %",
    ["passives.npc_counterattack.field.damageMin"] = "Damage min",
    ["passives.npc_counterattack.field.damageMax"] = "Damage max",
    ["passives.npc_counterattack.field.threshold"] = "Defense threshold",
    ["passives.npc_counterattack.field.defenseStat"] = "Defense stat",

    ["passives.poisonous.name"] = "Venomous",
    ["passives.poisonous.desc"] = "Chance to poison on a Strength attack (melee)",
    ["passives.poisonous.field.chance"] = "Chance %",
    ["passives.poisonous.field.dotValue"] = "Damage/round",
    ["passives.poisonous.field.dotDuration"] = "Duration",
    ["passives.poisonous.field.instantDamage"] = "Instant damage",

    ["passives.spell_reflection.name"] = "Spell Reflection",
    ["passives.spell_reflection.desc"] = "Chance to reflect a magic attack (Intelligence) back at the attacker",
    ["passives.spell_reflection.field.chance"] = "Chance %",

    ["passives.death_explosion.name"] = "Death Explosion",
    ["passives.death_explosion.desc"] = "When the NPC dies, the GM chooses who takes the damage",
    ["passives.death_explosion.field.damageMin"] = "Damage min",
    ["passives.death_explosion.field.damageMax"] = "Damage max",

    -- ─── SELF-BUFFS ───────────────────────────────────────
    ["passives.regeneration.name"] = "Regeneration",
    ["passives.regeneration.desc"] = "The NPC restores HP each round",
    ["passives.regeneration.field.value"] = "HP/round",

    ["passives.evasion.name"] = "Evasion",
    ["passives.evasion.desc"] = "Chance to fully dodge an attack",
    ["passives.evasion.field.chance"] = "Chance %",

    ["passives.resistance.name"] = "Resistance",
    ["passives.resistance.desc"] = "Reduces all incoming damage (at least 1 always goes through)",
    ["passives.resistance.field.value"] = "Damage reduction",

    ["passives.adaptation.name"] = "Adaptation",
    ["passives.adaptation.desc"] = "After 2+ attacks with the same stat, gains a defense bonus against that stat",
    ["passives.adaptation.field.value"] = "Defense bonus",

    ["passives.berserk.name"] = "Berserk",
    ["passives.berserk.desc"] = "Below 50% HP, a failed defense always triggers a counterattack with a stun",
    ["passives.berserk.field.damageMin"] = "Damage min",
    ["passives.berserk.field.damageMax"] = "Damage max",
    ["passives.berserk.field.threshold"] = "Defense threshold",
    ["passives.berserk.field.stunDuration"] = "Stun duration",

    -- ══════════════════════════════════════════════════════
    -- PASSIVE TRIGGERS (Data/Passives.lua)
    -- ══════════════════════════════════════════════════════
    ["passives.msg.regenerates"] = "%s regenerates %s HP (%d/%d)",
    ["passives.msg.adapts"] = "%s adapts to %s attacks! +%d to %s",
    ["passives.msg.explosion"] = "|cFFFF6600Explosion!|r %s takes %s damage!",
    ["passives.dlg.explode_btn"] = "|cFFFF6666Detonate|r",
    ["passives.dlg.title"] = "|cFFFF6600Death Explosion: %s|r",
    ["passives.dlg.info"] = "|cFF888888Damage: %s-%s. Choose targets:|r",
    ["passives.dlg.select_target"] = "Choose at least one target!",
})
