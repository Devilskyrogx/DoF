-- DoF/Locale/enUS/NPC.lua
-- NPC library: categories, templates, editor labels.

local ADDON_NAME, DoF = ...

DoF.Locale:Register("enUS", {

    -- ══════════════════════════════════════════════════════
    -- NPC LIBRARY (Data/NPCLibrary.lua, UI/NPCLibrary*.lua)
    -- ══════════════════════════════════════════════════════
    ["npc.new_template"] = "New NPC",
    ["npc.copy_suffix"] = "%s (copy)",
    ["npc.attack_default"] = "Attack",
    ["npc.attack_numbered"] = "Attack %s",
    ["npc.template_applied"] = "Template '%s' applied to %s",
    ["npc.template_applied_log"] = "Applied template '%s' to %s (HP:%s Frt:%s Rfl:%s Wil:%s)",
    ["npc.template_updated"] = "Template '%s' updated",
    ["npc.template_created"] = "Template '%s' created",

    -- Short stat and debuff labels in the template list
    ["npc.stat.fort_short"] = "Frt",
    ["npc.stat.reflex_short"] = "Rfl",
    ["npc.stat.will_short"] = "Wil",
    ["npc.stat.hybrid_short"] = "Hyb",
    ["npc.debuff.stun"] = "Stun",
    ["npc.debuff.weakness_damage"] = "Wk.dmg",
    ["npc.debuff.weakness_healing"] = "Wk.heal",
    ["npc.debuff.vuln_fortitude"] = "Vul.Frt",
    ["npc.debuff.vuln_reflex"] = "Vul.Rfl",
    ["npc.debuff.vuln_will"] = "Vul.Wil",
    ["npc.debuff.dot"] = "DoT",
    ["npc.debuff.generic"] = "debuff",

    -- Library window
    ["npc.ui.search"] = "Search...",
    ["npc.ui.create"] = "+ Create",
    ["npc.ui.attacks_divider"] = "--- Attacks ---",
    ["npc.ui.apply_to_target"] = "Apply to target",
    ["npc.ui.edit"] = "Edit",
    ["npc.ui.duplicate"] = "Copy",
    ["npc.ui.delete"] = "Delete",
    ["npc.ui.delete_confirm"] = "Sure?",
    ["npc.ui.no_templates"] = "No templates",
    ["npc.ui.no_category"] = "No category",
    ["npc.ui.choose_template"] = "Choose a template",
    ["npc.ui.stat_line"] = "   |cFF88CC88Frt:|r %s   |cFFFFCC66Rfl:|r %s   |cFF8888FFWil:|r %s",
    ["npc.ui.attack_line"] = "%s: %s / %s / %s",

    -- Template editor
    ["npc.edit.title_edit"] = "Edit template",
    ["npc.edit.title_new"] = "New template",
    ["npc.edit.name_label"] = "Name:",
    ["npc.edit.category_label"] = "Category:",
    ["npc.edit.fort_label"] = "Frt:",
    ["npc.edit.reflex_label"] = "Rfl:",
    ["npc.edit.will_label"] = "Wil:",
    ["npc.edit.damage_label"] = "Damage:",
    ["npc.edit.threshold_label"] = "Threshold:",
    ["npc.edit.defense_label"] = "Def:",
    ["npc.edit.debuff_label"] = "Dbf:",
    ["npc.edit.debuff_value_label"] = "Val:",
    ["npc.edit.debuff_duration_label"] = "R:",
    ["npc.edit.attacks_header"] = "Attacks",
    ["npc.edit.passives_header"] = "Passives",
    ["npc.edit.add"] = "+ Add",
    ["npc.edit.save"] = "Save",
    ["npc.edit.mode_guaranteed"] = "Guar.",
    ["npc.edit.mode_chance"] = "Chance",
    ["npc.edit.check_normal"] = "Normal",
    ["npc.edit.instant_on"] = "Instant dmg: ON",
    ["npc.edit.instant_off"] = "Instant dmg: off",

    -- Passive field labels in the editor (short, for narrow buttons)
    ["npc.field.mode"] = "Mode",
    ["npc.field.chance"] = "Chance%",
    ["npc.field.damageMin"] = "Min",
    ["npc.field.damageMax"] = "Max",
    ["npc.field.threshold"] = "Thresh",
    ["npc.field.dotValue"] = "Dmg/r",
    ["npc.field.dotDuration"] = "Rounds",
    ["npc.field.value"] = "Value",
    ["npc.field.stunDuration"] = "Stun(r)",
    ["npc.field.defenseStat"] = "Defense",
    ["npc.field.instantDamage"] = "Instant dmg",
})
