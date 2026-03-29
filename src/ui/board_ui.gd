## Board UI — Visual rendering and interaction for the Fidchell game board.
##
## Renders the 7×7 grid with tile types, pieces, highlights, and match info.
## Handles tap-to-select/move and drag-to-move input, piece slide animation,
## capture animation. Reads board state from BoardRules and updates visuals
## via signals. Responsive scaling for phone (4.7") to tablet (12.9") screens.
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

## Emitted when a move is submitted to BoardRules.
signal move_submitted(from: Vector2i, to: Vector2i)

## Emitted when a piece is selected by the player.
signal piece_selected(cell: Vector2i)

## Emitted when the current selection is cleared.
signal piece_deselected()

## Emitted when all animations for a move have completed.
signal animations_finished()


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

## Player's side (ATTACKER or DEFENDER).
var _player_side: int = -1

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


# --- Selection State ---

## Currently selected piece cell, or Vector2i(-1, -1) if none.
var _selected_cell: Vector2i = Vector2i(-1, -1)

## Legal move destinations for the selected piece.
var _legal_moves: Array = []

## Which legal moves result in captures (for distinct highlight).
var _capture_moves: Array = []

## Which legal moves are King escape moves (corner destinations).
var _king_escape_moves: Array = []

## Map of destination -> Array[Vector2i] of enemy pieces that would be captured.
var _capture_preview: Dictionary = {}

## Currently hovered legal move destination (for capture preview display).
var _hovered_cell: Vector2i = Vector2i(-1, -1)


# --- Animation State ---

## Whether animation is in progress (blocks input).
var _animating: bool = false

## Active tween for piece movement.
var _move_tween: Tween = null

## Moving piece: type, interpolated screen position, active flag.
var _moving_piece_type: int = 0
var _moving_piece_screen_pos: Vector2 = Vector2.ZERO
var _moving_piece_active: bool = false
var _moving_piece_dest_cell: Vector2i = Vector2i(-1, -1)

## Capture queue: Array of { piece_type: int, position: Vector2i }.
var _capture_queue: Array = []

## Capturing piece: type, screen position, opacity for fade.
var _capturing_piece_type: int = 0
var _capturing_piece_screen_pos: Vector2 = Vector2.ZERO
var _capturing_piece_opacity: float = 1.0
var _capturing_active: bool = false


# --- Drag State ---

## Whether a drag gesture is in progress.
var _dragging: bool = false

## Cell the drag started from.
var _drag_from_cell: Vector2i = Vector2i(-1, -1)

## Piece type being dragged.
var _drag_piece_type: int = 0

## Current drag screen position (follows finger/mouse).
var _drag_screen_pos: Vector2 = Vector2.ZERO

## Time of the initial press (for hold threshold detection).
var _press_time_ms: int = 0

## Position of the initial press (for drag distance detection).
var _press_position: Vector2 = Vector2.ZERO

## Whether we've committed to a drag (passed threshold).
var _drag_committed: bool = false

## Minimum drag distance in pixels before committing to drag.
const DRAG_DISTANCE_THRESHOLD: float = 8.0


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
	_player_side = state.player_side
	_match_active = state.match_active
	_last_move = {}
	_king_threat_count = 0
	_capture_preview = {}
	_hovered_cell = Vector2i(-1, -1)
	deselect_piece()
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


## Whether the board is currently animating (input blocked).
func is_animating() -> bool:
	return _animating


## Whether a piece is currently selected.
func has_selection() -> bool:
	return _selected_cell != Vector2i(-1, -1)


## Get the currently selected cell, or Vector2i(-1, -1) if none.
func get_selected_cell() -> Vector2i:
	return _selected_cell


## Get the legal move destinations for the selected piece.
func get_legal_moves() -> Array:
	return _legal_moves


## Force layout recalculation (e.g., after resize).
func recalculate_layout() -> void:
	_recalculate_layout()


# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------

## Select a piece at the given cell and compute its legal moves.
##
## Usage:
##   board_ui.select_piece(Vector2i(3, 2))
func select_piece(cell: Vector2i) -> void:
	if _board_rules == null:
		return

	var piece_type: int = get_piece_at(cell)
	if piece_type == 0:
		return

	# Only allow selecting own pieces
	if not _is_player_piece(piece_type):
		return

	_selected_cell = cell
	_legal_moves = []
	_capture_moves = []
	_king_escape_moves = []

	# Get legal destinations
	var destinations: Array = _board_rules.get_legal_moves(cell)
	for dest: Vector2i in destinations:
		_legal_moves.append(dest)

		# Check if this move would capture and identify victims
		var victims: Array = _get_capture_victims(cell, dest)
		if victims.size() > 0:
			_capture_moves.append(dest)
			_capture_preview[dest] = victims

		# Check if this is a King escape move (King moving to corner)
		if piece_type == 3 and _is_corner(dest):  # PieceType.KING == 3
			_king_escape_moves.append(dest)

	piece_selected.emit(cell)
	queue_redraw()


## Clear the current piece selection and cancel any active drag.
func deselect_piece() -> void:
	_selected_cell = Vector2i(-1, -1)
	_legal_moves = []
	_capture_moves = []
	_king_escape_moves = []
	_capture_preview = {}
	_hovered_cell = Vector2i(-1, -1)
	_dragging = false
	_drag_committed = false
	piece_deselected.emit()
	queue_redraw()


# ---------------------------------------------------------------------------
# Input Handling
# ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not _configured or not _match_active:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_handle_press(mb.position)
			else:
				_handle_release(mb.position)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_handle_drag_motion(mm.position)
		accept_event()


## Handle initial press — start potential drag or tap.
func _handle_press(pos: Vector2) -> void:
	if _animating:
		return
	if _active_side != _player_side:
		return

	var cell: Vector2i = screen_to_cell(pos)
	_press_time_ms = Time.get_ticks_msec()
	_press_position = pos
	_drag_committed = false

	# Check if pressing on a friendly piece — start potential drag
	if cell != Vector2i(-1, -1):
		var piece_type: int = get_piece_at(cell)
		if piece_type != 0 and _is_player_piece(piece_type):
			_dragging = true
			_drag_from_cell = cell
			_drag_piece_type = piece_type
			_drag_screen_pos = pos
			# Select the piece immediately to show legal moves
			select_piece(cell)
			return

	# Pressed on empty/enemy cell — not a drag candidate
	_dragging = false


## Handle drag motion — update dragged piece position and hover target.
func _handle_drag_motion(pos: Vector2) -> void:
	if not _dragging:
		return

	_drag_screen_pos = pos

	# Check if we've moved far enough to commit to a drag
	if not _drag_committed:
		var distance: float = pos.distance_to(_press_position)
		if distance >= DRAG_DISTANCE_THRESHOLD:
			_drag_committed = true

	# Update hovered cell for capture preview
	var cell: Vector2i = screen_to_cell(pos)
	if cell != _hovered_cell:
		_hovered_cell = cell

	queue_redraw()


## Handle release — either submit move (drag) or process as tap.
func _handle_release(pos: Vector2) -> void:
	if _animating:
		_dragging = false
		return
	if _active_side != _player_side:
		_dragging = false
		return

	var cell: Vector2i = screen_to_cell(pos)

	if _dragging and _drag_committed:
		# Drag release — submit if valid destination, cancel otherwise
		_dragging = false
		if cell != Vector2i(-1, -1) and _is_legal_destination(cell):
			_submit_player_move(_drag_from_cell, cell)
		else:
			# Cancel drag — piece snaps back, keep selection
			queue_redraw()
		return

	# Not a committed drag — treat as tap
	_dragging = false
	_handle_tap(cell)


func _handle_tap(cell: Vector2i) -> void:
	if cell == Vector2i(-1, -1):
		# Tapped outside board
		if has_selection():
			deselect_piece()
		return

	# If a piece is selected and we tapped a legal move destination
	if has_selection():
		if _is_legal_destination(cell):
			_submit_player_move(_selected_cell, cell)
			return

		# Tapped the already-selected piece → deselect
		if cell == _selected_cell:
			deselect_piece()
			return

		# Tapped a different friendly piece → switch selection
		var piece_type: int = get_piece_at(cell)
		if piece_type != 0 and _is_player_piece(piece_type):
			select_piece(cell)
			return

		# Tapped non-highlighted cell → deselect
		deselect_piece()
		return

	# No selection — try to select tapped piece
	var tapped_piece: int = get_piece_at(cell)
	if tapped_piece != 0 and _is_player_piece(tapped_piece):
		select_piece(cell)


func _submit_player_move(from: Vector2i, to: Vector2i) -> void:
	deselect_piece()
	_animating = true

	var result: Dictionary = _board_rules.submit_move(from, to)
	if not result.valid:
		_animating = false
		return

	move_submitted.emit(from, to)


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
	_draw_legal_move_highlights()
	_draw_capture_preview()
	_draw_selected_highlight()
	_draw_king_threat_indicator()
	_draw_pieces()
	_draw_animated_pieces()
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


func _draw_legal_move_highlights() -> void:
	if not has_selection():
		return

	for dest: Vector2i in _legal_moves:
		var color: Color
		if dest in _king_escape_moves:
			color = _config.color_king_escape
		elif dest in _capture_moves:
			color = _config.color_capture_move
		else:
			color = _config.color_legal_move

		var rect := Rect2(
			_board_origin + Vector2(dest.y * _cell_size, dest.x * _cell_size),
			Vector2(_cell_size, _cell_size)
		)
		draw_rect(rect, color)

		# Draw a dot in the center for non-capture moves
		if dest not in _capture_moves and dest not in _king_escape_moves:
			var center: Vector2 = cell_to_screen(dest)
			draw_circle(center, _cell_size * 0.12, Color(color, 0.7))


func _draw_capture_preview() -> void:
	if not has_selection() or _hovered_cell == Vector2i(-1, -1):
		return
	if not _capture_preview.has(_hovered_cell):
		return

	var victims: Array = _capture_preview[_hovered_cell]
	for victim_cell: Vector2i in victims:
		var center: Vector2 = cell_to_screen(victim_cell)
		var radius: float = _cell_size * 0.45
		# Draw X marker over threatened enemy
		draw_circle(center, radius, _config.color_capture_preview)


func _draw_selected_highlight() -> void:
	if not has_selection():
		return

	var rect := Rect2(
		_board_origin + Vector2(_selected_cell.y * _cell_size, _selected_cell.x * _cell_size),
		Vector2(_cell_size, _cell_size)
	)
	draw_rect(rect, _config.color_selected)


func _draw_king_threat_indicator() -> void:
	if _king_threat_count < 2 or _king_pos == Vector2i(-1, -1):
		return

	var center: Vector2 = cell_to_screen(_king_pos)
	var radius: float = _cell_size * 0.48
	draw_circle(center, radius, _config.color_king_threat)


func _draw_pieces() -> void:
	for cell: Vector2i in _pieces:
		# Skip pieces that are being animated
		if _moving_piece_active and cell == _moving_piece_dest_cell:
			continue

		# Skip piece being dragged (drawn separately at finger position)
		if _dragging and _drag_committed and cell == _drag_from_cell:
			continue

		var piece_type: int = _pieces[cell]
		var center: Vector2 = cell_to_screen(cell)

		_draw_piece_at(piece_type, center, 1.0)


func _draw_animated_pieces() -> void:
	# Draw moving piece at interpolated position
	if _moving_piece_active:
		_draw_piece_at(_moving_piece_type, _moving_piece_screen_pos, 1.0)

	# Draw capturing piece with fading opacity
	if _capturing_active:
		_draw_piece_at(_capturing_piece_type, _capturing_piece_screen_pos, _capturing_piece_opacity)

	# Draw dragged piece at finger/mouse position
	if _dragging and _drag_committed:
		_draw_piece_at(_drag_piece_type, _drag_screen_pos, 0.85)


func _draw_piece_at(piece_type: int, center: Vector2, opacity: float) -> void:
	if piece_type == 1:  # PieceType.ATTACKER
		_draw_attacker(center, opacity)
	elif piece_type == 2:  # PieceType.DEFENDER
		_draw_defender(center, opacity)
	elif piece_type == 3:  # PieceType.KING
		_draw_king(center, opacity)


## Draw attacker as octagon (angular shape — distinguishable from round defenders).
func _draw_attacker(center: Vector2, opacity: float = 1.0) -> void:
	var radius: float = _cell_size * _config.piece_radius_fraction
	_build_octagon(center, radius)

	var fill_color := Color(_config.color_attacker, _config.color_attacker.a * opacity)
	var outline_color := Color(_config.color_attacker_outline, _config.color_attacker_outline.a * opacity)

	draw_colored_polygon(_octagon_points, fill_color)
	for i: int in _octagon_points.size():
		var next: int = (i + 1) % _octagon_points.size()
		draw_line(
			_octagon_points[i], _octagon_points[next],
			outline_color, _config.piece_outline_width
		)


## Draw defender as circle (round shape — distinguishable from angular attackers).
func _draw_defender(center: Vector2, opacity: float = 1.0) -> void:
	var radius: float = _cell_size * _config.piece_radius_fraction

	var fill_color := Color(_config.color_defender, _config.color_defender.a * opacity)
	var outline_color := Color(_config.color_defender_outline, _config.color_defender_outline.a * opacity)

	draw_circle(center, radius, fill_color)
	_draw_circle_outline(center, radius, outline_color, _config.piece_outline_width)


## Draw king as larger circle with gold band cross marker.
func _draw_king(center: Vector2, opacity: float = 1.0) -> void:
	var radius: float = _cell_size * _config.king_radius_fraction

	var fill_color := Color(_config.color_king, _config.color_king.a * opacity)
	var outline_color := Color(_config.color_king_outline, _config.color_king_outline.a * opacity)
	var band_color := Color(_config.color_king_band, _config.color_king_band.a * opacity)

	# Main body
	draw_circle(center, radius, fill_color)
	_draw_circle_outline(center, radius, outline_color, _config.piece_outline_width)

	# Crown cross marker (horizontal + vertical bars)
	var bar_half: float = radius * 0.4
	var bar_width: float = radius * 0.2
	# Horizontal bar
	draw_rect(Rect2(
		center + Vector2(-bar_half, -bar_width * 0.5),
		Vector2(bar_half * 2.0, bar_width)
	), band_color)
	# Vertical bar
	draw_rect(Rect2(
		center + Vector2(-bar_width * 0.5, -bar_half),
		Vector2(bar_width, bar_half * 2.0)
	), band_color)


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
# Animation
# ---------------------------------------------------------------------------

## Animate a piece sliding from one cell to another.
func _animate_move(piece_type: int, from: Vector2i, to: Vector2i) -> void:
	_moving_piece_type = piece_type
	_moving_piece_screen_pos = cell_to_screen(from)
	_moving_piece_dest_cell = to
	_moving_piece_active = true

	var target_pos: Vector2 = cell_to_screen(to)

	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()

	_move_tween = create_tween()
	_move_tween.tween_property(self, "_moving_piece_screen_pos", target_pos, _config.move_anim_duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_move_tween.tween_callback(_on_move_animation_finished)

	# Redraw each frame during animation
	_move_tween.set_parallel(false)


## Called when the move animation tween completes.
func _on_move_animation_finished() -> void:
	_moving_piece_active = false
	_moving_piece_dest_cell = Vector2i(-1, -1)

	# Process any queued captures
	if _capture_queue.size() > 0:
		_process_next_capture()
	else:
		_finish_animation_sequence()


## Process the next capture in the queue.
func _process_next_capture() -> void:
	if _capture_queue.size() == 0:
		_finish_animation_sequence()
		return

	var capture: Dictionary = _capture_queue.pop_front()
	var pos: Vector2i = capture.position
	var piece_type: int = capture.piece_type

	_capturing_piece_type = piece_type
	_capturing_piece_screen_pos = cell_to_screen(pos)
	_capturing_piece_opacity = 1.0
	_capturing_active = true

	# Remove from pieces immediately (so it doesn't double-draw)
	if _pieces.has(pos):
		_pieces.erase(pos)

	var capture_tween: Tween = create_tween()
	capture_tween.tween_property(self, "_capturing_piece_opacity", 0.0, _config.capture_anim_duration)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	capture_tween.tween_callback(_on_capture_animation_finished)


## Called when a capture animation completes.
func _on_capture_animation_finished() -> void:
	_capturing_active = false

	# Pause between captures
	if _capture_queue.size() > 0:
		var gap_tween: Tween = create_tween()
		gap_tween.tween_interval(_config.multi_capture_gap)
		gap_tween.tween_callback(_process_next_capture)
	else:
		_finish_animation_sequence()


## Complete the animation sequence and unblock input.
func _finish_animation_sequence() -> void:
	_animating = false
	animations_finished.emit()
	queue_redraw()


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

	_safe_connect("piece_moved", _on_piece_moved)
	_safe_connect("piece_captured", _on_piece_captured)
	_safe_connect("turn_changed", _on_turn_changed)
	_safe_connect("match_ended", _on_match_ended)
	_safe_connect("king_threatened", _on_king_threatened)


## Connect to a signal only if not already connected.
func _safe_connect(signal_name: String, callable: Callable) -> void:
	if _board_rules.has_signal(signal_name):
		var sig: Signal = Signal(_board_rules, signal_name)
		if not sig.is_connected(callable):
			sig.connect(callable)


func _on_piece_moved(piece_type: int, from_pos: Vector2i, to_pos: Vector2i) -> void:
	# Update internal state
	if _pieces.has(from_pos):
		_pieces.erase(from_pos)
	_pieces[to_pos] = piece_type

	if piece_type == 3:  # PieceType.KING
		_king_pos = to_pos

	_last_move = { "from": from_pos, "to": to_pos }

	# Start animation
	_animating = true
	_animate_move(piece_type, from_pos, to_pos)


func _on_piece_captured(piece_type: int, cap_pos: Vector2i, _captured_by: Vector2i) -> void:
	# Queue capture for sequential animation after move completes
	_capture_queue.append({ "piece_type": piece_type, "position": cap_pos })


func _on_turn_changed(new_active_side: int) -> void:
	_active_side = new_active_side
	queue_redraw()


func _on_match_ended(_result: Dictionary) -> void:
	_match_active = false
	deselect_piece()
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


# ---------------------------------------------------------------------------
# Query helpers
# ---------------------------------------------------------------------------

## Check if a piece type belongs to the player's side.
func _is_player_piece(piece_type: int) -> bool:
	if _player_side == 0:  # Side.ATTACKER
		return piece_type == 1  # PieceType.ATTACKER
	else:  # Side.DEFENDER
		return piece_type == 2 or piece_type == 3  # DEFENDER or KING


## Check if a destination is in the legal moves list.
func _is_legal_destination(cell: Vector2i) -> bool:
	for dest: Vector2i in _legal_moves:
		if dest == cell:
			return true
	return false


## Check if a cell is a corner tile.
func _is_corner(cell: Vector2i) -> bool:
	return _tile_types.has(cell) and _tile_types[cell] == 2  # TileType.CORNER


## Get the enemy pieces that would be captured by moving from src to dest.
## Returns Array[Vector2i] of victim cell positions (empty if no captures).
func _get_capture_victims(src: Vector2i, dest: Vector2i) -> Array:
	if _board_rules == null:
		return []

	var victims: Array = []
	var piece_type: int = get_piece_at(src)
	var is_attacker: bool = (piece_type == 1)

	var directions: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for dir: Vector2i in directions:
		var adj: Vector2i = dest + dir
		var beyond: Vector2i = adj + dir

		if not _board_rules.is_in_bounds(adj) or not _board_rules.is_in_bounds(beyond):
			continue

		var adj_piece: int = get_piece_at(adj)
		var beyond_piece: int = get_piece_at(beyond)

		if adj_piece == 0:
			continue

		if is_attacker:
			if adj_piece == 2 and (beyond_piece == 1 or _board_rules.get_tile_type(beyond) != 0):
				victims.append(adj)
		else:
			if adj_piece == 1 and (beyond_piece == 2 or beyond_piece == 3 or _board_rules.get_tile_type(beyond) != 0):
				victims.append(adj)

	return victims


# ---------------------------------------------------------------------------
# Process (for animation redraw)
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _moving_piece_active or _capturing_active:
		queue_redraw()
