## Custom Resource defining an AI opponent's full configuration.
##
## Combines character identity with AI configuration: difficulty level,
## personality weights, and think time. Loaded from .tres files and
## used by CampaignSystem to configure AISystem per match.
##
## Usage:
##   var profile := preload("res://assets/data/opponents/seanan.tres") as OpponentProfile
##   ai_system.configure(board_rules, side)
##   profile.apply_to(ai_system)
##
## See: design/gdd/ai-system.md (Section 6)
class_name OpponentProfile
extends Resource


## Character display name.
@export var character_name: String = ""

## Character ID (snake_case, used for lookups).
@export var character_id: String = ""

## Base difficulty level (1-7).
@export var difficulty: int = 1

## Personality weight profile resource.
@export var personality: AIPersonalityData = null

## Optional description for debug/editor display.
@export var description: String = ""


## Apply this opponent's configuration to an AI system instance.
##
## Usage:
##   profile.apply_to(ai_system)
func apply_to(ai_system: Node) -> void:
	ai_system.apply_difficulty(difficulty)
	if personality != null:
		ai_system.w_material = personality.w_material
		ai_system.w_king_freedom = personality.w_king_freedom
		ai_system.w_king_proximity = personality.w_king_proximity
		ai_system.w_board_control = personality.w_board_control
		ai_system.w_threat = personality.w_threat
		ai_system.erratic_disruption_chance = personality.erratic_disruption_chance
