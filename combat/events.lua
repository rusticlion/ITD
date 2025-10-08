local Events = {
    -- State transitions
    COMBAT_START = "combat_start",
    ROUND_START = "round_start",
    UPKEEP_PHASE = "upkeep_phase",
    TECH_SELECT_PHASE = "tech_select_phase",
    ATTACK_ASSIGN_PHASE = "attack_assign_phase",
    DEFENSE_ASSIGN_PHASE = "defense_assign_phase",
    RESOLUTION_PHASE = "resolution_phase",
    ROUND_END = "round_end",
    COMBAT_END = "combat_end",

    -- Actions
    TECH_SELECTED = "tech_selected",
    ATTACK_ASSIGNED = "attack_assigned",
    DEFENSE_ASSIGNED = "defense_assigned",
    DICE_ROLLED = "dice_rolled",
    DIE_REROLLED = "die_rerolled",
    DAMAGE_DEALT = "damage_dealt",
    BP_STATUS_CHANGED = "bp_status_changed",
    CREST_GAINED = "crest_gained",
    CREST_EXPENDED = "crest_expended",

    -- UI hints
    AWAIT_PLAYER_INPUT = "await_player_input",
    SHOW_RESULT = "show_result"
}

return Events
