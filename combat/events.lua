local Events = {
    -- State transitions
    COMBAT_START = "combat_start",
    ROUND_START = "round_start",
    UPKEEP_PHASE = "upkeep_phase",
    ROLL_PHASE = "roll_phase",
    ALLOCATION_PHASE = "allocation_phase",
    RESOLUTION_PHASE = "resolution_phase",
    ROUND_END = "round_end",
    COMBAT_END = "combat_end",

    -- Actions
    DICE_ROLLED = "dice_rolled",
    DIE_ASSIGNED = "die_assigned",
    SLOT_FED = "slot_fed",
    SLOT_TRIGGERED = "slot_triggered",
    SLOT_RESOLVED = "slot_resolved",
    SLOT_CHARGE_VENTED = "slot_charge_vented",
    SLOT_COST_CHANGED = "slot_cost_changed",
    SPELLMARK_OPENED = "spellmark_opened",
    SPELLMARK_RESOLVED = "spellmark_resolved",
    KEYWORD_TRIGGERED = "keyword_triggered",
    LATCH_EJECTED = "latch_ejected",
    PART_RESOLVED = "part_resolved",
    DAMAGE_DEALT = "damage_dealt",
    BP_STATUS_CHANGED = "bp_status_changed",
    HEAL_APPLIED = "heal_applied",
    CREST_GAINED = "crest_gained",
    CREST_EXPENDED = "crest_expended"
}

return Events
