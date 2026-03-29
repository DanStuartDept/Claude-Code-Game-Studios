## Custom Resource defining all Board UI visual parameters.
##
## Externalises colors, sizes, and timing values so the board can be
## reskinned or tuned without touching code. Loaded from .tres files.
##
## Usage:
##   var config := preload("res://assets/data/ui/default_board_ui.tres") as BoardUIConfig
##   board_ui.configure(board_rules, config)
##
## See: design/gdd/board-ui.md (Tuning Knobs)
class_name BoardUIConfig
extends Resource


# --- Layout ---

## Minimum touch target size in points (Apple HIG: 44pt).
@export var min_tap_target: float = 44.0

## Maximum cell size in points (caps board on large screens).
@export var max_cell_size: float = 100.0

## Vertical margin reserved for match info (opponent/player panels).
@export var ui_margin: float = 120.0


# --- Tile Colors ---

## Normal tile background color (wood).
@export var color_normal_tile: Color = Color(0.76, 0.64, 0.46)

## Throne tile background color (golden).
@export var color_throne_tile: Color = Color(0.85, 0.72, 0.42)

## Corner tile background color (darker wood).
@export var color_corner_tile: Color = Color(0.70, 0.58, 0.38)

## Grid line color (ink).
@export var color_grid_line: Color = Color(0.2, 0.15, 0.1, 0.6)

## Board border color.
@export var color_board_border: Color = Color(0.15, 0.1, 0.05, 0.8)


# --- Piece Colors ---

## Attacker piece color (dark stone).
@export var color_attacker: Color = Color(0.25, 0.22, 0.2)

## Attacker piece outline.
@export var color_attacker_outline: Color = Color(0.1, 0.08, 0.05)

## Defender piece color (light stone).
@export var color_defender: Color = Color(0.82, 0.75, 0.62)

## Defender piece outline.
@export var color_defender_outline: Color = Color(0.5, 0.45, 0.35)

## King piece color (gold).
@export var color_king: Color = Color(0.9, 0.82, 0.55)

## King band/crown accent color.
@export var color_king_band: Color = Color(0.85, 0.7, 0.2)

## King piece outline.
@export var color_king_outline: Color = Color(0.55, 0.45, 0.15)


# --- Highlight Colors ---

## Legal move destination highlight.
@export var color_legal_move: Color = Color(0.3, 0.7, 0.3, 0.4)

## Capture move highlight (stronger).
@export var color_capture_move: Color = Color(0.8, 0.3, 0.2, 0.5)

## King escape corner highlight.
@export var color_king_escape: Color = Color(0.9, 0.8, 0.2, 0.5)

## Selected piece highlight.
@export var color_selected: Color = Color(0.4, 0.6, 0.9, 0.5)

## Last move origin highlight.
@export var color_last_move_from: Color = Color(0.5, 0.5, 0.3, 0.3)

## Last move destination highlight.
@export var color_last_move_to: Color = Color(0.6, 0.6, 0.3, 0.3)

## King threat indicator color.
@export var color_king_threat: Color = Color(0.9, 0.2, 0.1, 0.4)

## Capture preview highlight color (marks enemies that will be taken).
@export var color_capture_preview: Color = Color(0.95, 0.2, 0.1, 0.55)


# --- Piece Sizing ---

## Piece radius as fraction of cell size (standard pieces).
@export var piece_radius_fraction: float = 0.35

## King radius as fraction of cell size (slightly larger).
@export var king_radius_fraction: float = 0.40

## Piece outline width.
@export var piece_outline_width: float = 2.0

## Grid line width.
@export var grid_line_width: float = 1.5

## Board border width.
@export var board_border_width: float = 3.0


# --- Animation Timing (used by S1-08) ---

## Piece move animation duration in seconds.
@export var move_anim_duration: float = 0.25

## Piece capture animation duration in seconds.
@export var capture_anim_duration: float = 0.3

## Gap between sequential captures in seconds.
@export var multi_capture_gap: float = 0.1

## Drag hold threshold in milliseconds.
@export var drag_hold_threshold_ms: int = 150

## Result pause before overlay in seconds.
@export var result_pause_duration: float = 0.5

## Last move highlight opacity.
@export var last_move_highlight_opacity: float = 0.3
