## Board UI — Visual rendering of the Fidchell game board.
##
## Renders the 7×7 grid with tile types, pieces, highlights, and match info.
## Reads board state from BoardRules and updates visuals via signals.
## Responsive scaling for phone (4.7") to tablet (12.9") screens.
##
## Architecture: Core Layer (ADR-0001). Depends on Board Rules Engine.
## See: design/gdd/board-ui.md
##
## Usage:
##   var board_ui := BoardUI.new()
##   board_ui.configure(board_rules_node, config_resource)
class_name BoardUI
extends Control


# --- Signals ---

## Emitted when the board layout is recalculated (e.g., on resize).
signal layout_changed(cell_size: float, board_origin: Vector2)


# --- Configuration ---

## Visual configuration resource.
var _config: BoardUIConfig = null

## Reference to the Board Rules Engine.
var _board_rules: Node = null

## Whether the board has been configured and is ready to render.
var _configured: bool = false


# --- Layout State (recalculated on resize) ---

## Computed cell size in pixels.
var _cell_size: float = 0.0

## Top-left corner of the board grid in local coordinates.
var _board_origin: Vector2 = Vector2.ZERO

## Board size in cells (read from BoardRules).
var _board_size: int = 7


# --- Board State (updated from BoardRules signals) ---

## Current piece positions: { Vector2i: PieceType (int) }.
var _pieces: Dictionary = {}

## Current active side.
var _active_side: int = -1

## King position for threat rendering.
var _king_pos: Vector2i = Vector2i(-1, -1)

## King threat count (0 = safe).
var _king_threat_count: int = 0

## Last move for highlight: { from: Vector2i, to: Vector2i } or empty.
var _last_move: Dictionary = {}

## Tile type cache: { Vector2i: TileType (int) }.
var _tile_types: Dictionary = {}

## Whether the match is active.
var _match_active: bool = false


# --- Pre-allocated draw arrays (zero-alloc hot path) ---

## Octagon vertices for attacker piece (reused per draw).
var _octagon_points: PackedVector2Array = PackedVector2Array()

## Cross vertices for king crown marker (reused per draw).
var _crown_points: PackedVector2Array = PackedVector2Array()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Configure the board UI with a rules engine and visual config.
##
## Usage:
##   board_ui.configure(board_rules_node, config_resource)
func configure(board_rules: Node, config: Resource = null) -> void:
	_board_rules = board_rules
	if config != null and config is BoardUIConfig:
		_config = config as BoardUIConfig
	else:
		_config = BoardUIConfig.new()

	_board_size = _board_rules.board_size

	_connect_signals()
	_cache_tile_types()
	_pre_allocate_shapes()
	_configured = true

	_recalculate_layout()
	populate_board()


## Read current board state from BoardRules and update rendering.
##
## Usage:
##   board_ui.populate_board()
func populate_board() -> void:
	if _board_rules == null:
		return

	_pieces.clear()
	var state: Dictionary = _board_rules.get_board_state()
	var grid: Array = state.grid

	for row: int in _board_size:
		for col: int in _board_size:
			var piece_type: int = grid[row][col]
			if piece_type != 0:  # PieceType.NONE == 0
				_pieces[Vector2i(row, col)] = piece_type
				if piece_type == 3:  # PieceType.KING == 3
					_king_pos = Vector2i(row, col)

	_active_side = state.active_side
	_match_active = state.match_active
	_last_move = {}
	_king_threat_count = 0
	queue_redraw()


## Convert a grid cell position to screen (local) coordinates.
## Returns the center point of the cell.
##
## Usage:
##   var screen_pos: Vector2 = board_ui.cell_to_screen(Vector2i(3, 3))
func cell_to_screen(cell: Vector2i) -> Vector2:
	var x: float = _board_origin.x + (cell.y + 0.5) * _cell_size
	var y: float = _board_origin.y + (cell.x + 0.5) * _cell_size
	return Vector2(x, y)


## Convert a screen (local) position to a grid cell.
## Returns Vector2i(-1, -1) if outside the board.
##
## Usage:
##   var cell: Vector2i = board_ui.screen_to_cell(touch_position)
func screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var local_x: float = screen_pos.x - _board_origin.x
	var local_y: float = screen_pos.y - _board_origin.y

	if local_x < 0.0 or local_y < 0.0:
		return Vector2i(-1, -1)

	var col: int = int(local_x / _cell_size)
	var row: int = int(local_y / _cell_size)

	if row < 0 or row >= _board_size or col < 0 or col >= _board_size:
		return Vector2i(-1, -1)

	return Vector2i(row, col)


## Get the current computed cell size.
func get_cell_size() -> float:
	return _cell_size


## Get the current board origin in local coordinates.
func get_board_origin() -> Vector2:
	return _board_origin


## Get the piece type at a grid position, or 0 (NONE) if empty.
func get_piece_at(cell: Vector2i) -> int:
	if _pieces.has(cell):
		return _pieces[cell]
	return 0


## Force layout recalculation (e.g., after resize).
func recalculate_layout() -> void:
	_recalculate_layout()


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _configured:
		_recalculate_layout()
		queue_redraw()


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	if not _configured:
		return

	_draw_board_background()
	_draw_tile_backgrounds()
	_draw_grid_lines()
	_draw_last_move_highlight()
	_draw_king_threat_indicator()
	_draw_pieces()
	_draw_board_border()


func _draw_board_background() -> void:
	var board_rect := Rect2(
		_board_origin,
		Vector2(_board_size * _cell_size, _board_size * _cell_size)
	)
	draw_rect(board_rect, _config.color_normal_tile)


func _draw_tile_backgrounds() -> void:
	for cell: Vector2i in _tile_types:
		var tile_type: int = _tile_types[cell]
		if tile_type == 0:  # TileType.NORMAL
			continue

		var color: Color
		if tile_type == 1:  # TileType.THRONE
			color = _config.color_throne_tile
		else:  # TileType.CORNER
			color = _config.color_corner_tile

		var rect := Rect2(
			_board_origin + Vector2(cell.y * _cell_size, cell.x * _cell_size),
			Vector2(_cell_size, _cell_size)
		)
		draw_rect(rect, color)


func _draw_grid_lines() -> void:
	var board_pixel_size: float = _board_size * _cell_size

	# Vertical lines
	for col: int in range(_board_size + 1):
		var x: float = _board_origin.x + col * _cell_size
		var from := Vector2(x, _board_origin.y)
		var to := Vector2(x, _board_origin.y + board_pixel_size)
		draw_line(from, to, _config.color_grid_line, _config.grid_line_width)

	# Horizontal lines
	for row: int in range(_board_size + 1):
		var y: float = _board_origin.y + row * _cell_size
		var from := Vector2(_board_origin.x, y)
		var to := Vector2(_board_origin.x + board_pixel_size, y)
		draw_line(from, to, _config.color_grid_line, _config.grid_line_width)


func _draw_last_move_highlight() -> void:
	if _last_move.is_empty():
		return

	var from_cell: Vector2i = _last_move.from
	var to_cell: Vector2i = _last_move.to

	var from_rect := Rect2(
		_board_origin + Vector2(from_cell.y * _cell_size, from_cell.x * _cell_size),
		Vector2(_cell_size, _cell_size)
	)
	draw_rect(from_rect, _config.color_last_move_from)

	var to_rect := Rect2(
		_board_origin + Vector2(to_cell.y * _cell_size, to_cell.x * _cell_size),
		Vector2(_cell_size, _cell_size)
	)
	draw_rect(to_rect, _config.color_last_move_to)


func _draw_king_threat_indicator() -> void:
	if _king_threat_count < 2 or _king_pos == Vector2i(-1, -1):
		return

	var center: Vector2 = cell_to_screen(_king_pos)
	var radius: float = _cell_size * 0.48
	draw_circle(center, radius, _config.color_king_threat)


func _draw_pieces() -> void:
	for cell: Vector2i in _pieces:
		var piece_type: int = _pieces[cell]
		var center: Vector2 = cell_to_screen(cell)

		if piece_type == 1:  # PieceType.ATTACKER
			_draw_attacker(center)
		elif piece_type == 2:  # PieceType.DEFENDER
			_draw_defender(center)
		elif piece_type == 3:  # PieceType.KING
			_draw_king(center)


## Draw attacker as octagon (angular shape — distinguishable from round defenders).
func _draw_attacker(center: Vector2) -> void:
	var radius: float = _cell_size * _config.piece_radius_fraction
	_build_octagon(center, radius)

	draw_colored_polygon(_octagon_points, _config.color_attacker)
	for i: int in _octagon_points.size():
		var next: int = (i + 1) % _octagon_points.size()
		draw_line(
			_octagon_points[i], _octagon_points[next],
			_config.color_attacker_outline, _config.piece_outline_width
		)


## Draw defender as circle (round shape — distinguishable from angular attackers).
func _draw_defender(center: Vector2) -> void:
	var radius: float = _cell_size * _config.piece_radius_fraction

	draw_circle(center, radius, _config.color_defender)
	_draw_circle_outline(center, radius, _config.color_defender_outline, _config.piece_outline_width)


## Draw king as larger circle with gold band cross marker.
func _draw_king(center: Vector2) -> void:
	var radius: float = _cell_size * _config.king_radius_fraction

	# Main body
	draw_circle(center, radius, _config.color_king)
	_draw_circle_outline(center, radius, _config.color_king_outline, _config.piece_outline_width)

	# Crown cross marker (horizontal + vertical bars)
	var bar_half: float = radius * 0.4
	var bar_width: float = radius * 0.2
	# Horizontal bar
	draw_rect(Rect2(
		center + Vector2(-bar_half, -bar_width * 0.5),
		Vector2(bar_half * 2.0, bar_width)
	), _config.color_king_band)
	# Vertical bar
	draw_rect(Rect2(
		center + Vector2(-bar_width * 0.5, -bar_half),
		Vector2(bar_width, bar_half * 2.0)
	), _config.color_king_band)


func _draw_board_border() -> void:
	var board_rect := Rect2(
		_board_origin,
		Vector2(_board_size * _cell_size, _board_size * _cell_size)
	)
	draw_rect(board_rect, _config.color_board_border, false, _config.board_border_width)


# ---------------------------------------------------------------------------
# Draw helpers
# ---------------------------------------------------------------------------

## Draw a circle outline using line segments (Godot draw_arc alternative).
func _draw_circle_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
	var point_count: int = 24
	var angle_step: float = TAU / point_count
	for i: int in point_count:
		var angle_a: float = i * angle_step
		var angle_b: float = (i + 1) * angle_step
		var from := center + Vector2(cos(angle_a), sin(angle_a)) * radius
		var to := center + Vector2(cos(angle_b), sin(angle_b)) * radius
		draw_line(from, to, color, width)


## Build octagon vertices into the pre-allocated array.
func _build_octagon(center: Vector2, radius: float) -> void:
	_octagon_points.resize(8)
	var angle_step: float = TAU / 8.0
	var offset: float = TAU / 16.0  # Rotate 22.5° so flat edge is on top
	for i: int in 8:
		var angle: float = offset + i * angle_step
		_octagon_points[i] = center + Vector2(cos(angle), sin(angle)) * radius


# ---------------------------------------------------------------------------
# Layout calculation
# ---------------------------------------------------------------------------

func _recalculate_layout() -> void:
	if _config == null:
		return

	var available_width: float = size.x
	var available_height: float = size.y - _config.ui_margin

	# Cell size: fill available space, respect min/max
	_cell_size = minf(available_width, available_height) / _board_size
	_cell_size = maxf(_cell_size, _config.min_tap_target)
	_cell_size = minf(_cell_size, _config.max_cell_size)

	# Center the board in available space
	var board_pixel_size: float = _board_size * _cell_size
	var offset_x: float = (available_width - board_pixel_size) * 0.5
	var offset_y: float = (_config.ui_margin * 0.5) + (available_height - board_pixel_size) * 0.5

	_board_origin = Vector2(maxf(offset_x, 0.0), maxf(offset_y, 0.0))

	layout_changed.emit(_cell_size, _board_origin)


# ---------------------------------------------------------------------------
# Signal connections
# ---------------------------------------------------------------------------

func _connect_signals() -> void:
	if _board_rules == null:
		return

	if _board_rules.has_signal("piece_moved"):
		_board_rules.piece_moved.connect(_on_piece_moved)
	if _board_rules.has_signal("piece_captured"):
		_board_rules.piece_captured.connect(_on_piece_captured)
	if _board_rules.has_signal("turn_changed"):
		_board_rules.turn_changed.connect(_on_turn_changed)
	if _board_rules.has_signal("match_ended"):
		_board_rules.match_ended.connect(_on_match_ended)
	if _board_rules.has_signal("king_threatened"):
		_board_rules.king_threatened.connect(_on_king_threatened)


func _on_piece_moved(piece_type: int, from_pos: Vector2i, to_pos: Vector2i) -> void:
	# Update internal piece state (animation added in S1-08)
	if _pieces.has(from_pos):
		_pieces.erase(from_pos)
	_pieces[to_pos] = piece_type

	if piece_type == 3:  # PieceType.KING
		_king_pos = to_pos

	_last_move = { "from": from_pos, "to": to_pos }
	queue_redraw()


func _on_piece_captured(piece_type: int, position: Vector2i, _captured_by: Vector2i) -> void:
	# Remove captured piece (animation added in S1-08)
	if _pieces.has(position):
		_pieces.erase(position)
	queue_redraw()


func _on_turn_changed(new_active_side: int) -> void:
	_active_side = new_active_side
	queue_redraw()


func _on_match_ended(_result: Dictionary) -> void:
	_match_active = false
	queue_redraw()


func _on_king_threatened(king_pos: Vector2i, threat_count: int) -> void:
	_king_pos = king_pos
	_king_threat_count = threat_count
	queue_redraw()


# ---------------------------------------------------------------------------
# Initialisation helpers
# ---------------------------------------------------------------------------

## Cache tile types for all special cells to avoid per-frame lookups.
func _cache_tile_types() -> void:
	_tile_types.clear()
	for row: int in _board_size:
		for col: int in _board_size:
			var pos := Vector2i(row, col)
			var tile_type: int = _board_rules.get_tile_type(pos)
			if tile_type != 0:  # Only cache non-normal tiles
				_tile_types[pos] = tile_type


## Pre-allocate reusable shape arrays (zero-alloc hot path).
func _pre_allocate_shapes() -> void:
	_octagon_points.resize(8)
	_crown_points.resize(12)
