## Custom Resource defining a Fidchell board layout.
##
## Contains all configurable board parameters: grid size, special tile positions,
## starting piece positions, and tuning knobs. Loaded from .tres files and applied
## to BoardRules at match start.
##
## Usage:
##   var layout := preload("res://assets/data/board/default_layout.tres") as BoardLayout
##   BoardRules.layout = layout
##   BoardRules.start_match()
##
## See: docs/architecture/adr-0001-core-game-architecture.md (Section 5)
class_name BoardLayout
extends Resource


## Width and height of the square board grid.
@export var board_size: int = 7

## Position of the throne tile (center of the board).
@export var throne_pos: Vector2i = Vector2i(3, 3)

## Positions of the four corner escape tiles.
@export var corner_positions: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, 6), Vector2i(6, 0), Vector2i(6, 6)
]

## Starting positions for attacker pieces.
@export var attacker_start_positions: Array[Vector2i] = [
	Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4),
	Vector2i(1, 3),
	Vector2i(2, 0), Vector2i(2, 6),
	Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 5), Vector2i(3, 6),
	Vector2i(4, 0), Vector2i(4, 6),
	Vector2i(5, 3),
	Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4),
]

## Starting positions for defender pieces (excluding King).
@export var defender_start_positions: Array[Vector2i] = [
	Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4),
	Vector2i(3, 2), Vector2i(3, 4),
	Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4),
]

## Starting position for the King piece.
@export var king_start_pos: Vector2i = Vector2i(3, 3)

## Number of adjacent attackers required to emit the king_threatened signal.
@export var king_threatened_threshold: int = 2

## Number of sides required to capture the King.
@export var king_capture_sides: int = 4
