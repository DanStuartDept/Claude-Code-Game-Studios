## Custom Resource defining an AI personality weight profile.
##
## Adjusts evaluation weights to produce distinct play styles.
## Loaded from .tres files and applied to AISystem.
##
## Usage:
##   var pers := preload("res://assets/data/ai/defensive.tres") as AIPersonalityData
##   ai_system.w_material = pers.w_material
##
## See: design/gdd/ai-system.md (Section 4)
class_name AIPersonalityData
extends Resource


## Display name of this personality type.
@export var personality_name: String = "Balanced"

## Weight for piece count advantage.
@export var w_material: float = 1.0

## Weight for King mobility.
@export var w_king_freedom: float = 1.0

## Weight for King distance to corners.
@export var w_king_proximity: float = 1.0

## Weight for positional board control.
@export var w_board_control: float = 1.0

## Weight for immediate tactical threats.
@export var w_threat: float = 1.0

## Chance for erratic disruption (0.0 for non-erratic personalities).
@export var erratic_disruption_chance: float = 0.0
