## GdUnit4 tests for Board UI — Input & Animation (S1-08)
##
## Covers S1-08 acceptance criteria:
## - Tap selects piece and shows legal moves
## - Tap destination submits move
## - Tap different piece switches selection
## - Tap empty/same deselects
## - Input blocked during animation
## - Only player's pieces selectable
## - Legal move highlights include capture/escape distinction
class_name TestBoardInput
extends GdUnitTestSuite


const BoardRulesScript := preload("res://src/core/board_rules.gd")
const BoardUIScript := preload("res://src/ui/board_ui.gd")
const BoardUIConfigScript := preload("res://src/data/board_ui_config.gd")

var _board: Node
var _ui: Control


func before_test() -> void:
	_board = BoardRulesScript.new()
	add_child(_board)
	_ui = BoardUIScript.new()
	_ui.size = Vector2(400, 520)
	add_child(_ui)


func after_test() -> void:
	_ui.queue_free()
	_board.queue_free()


# --- Helpers ---

func _setup(player_side: int = 1) -> void:
	# player_side: 0 = ATTACKER, 1 = DEFENDER
	_board.start_match(_board.MatchMode.STANDARD, player_side)
	var config: BoardUIConfig = BoardUIConfigScript.new()
	# Use instant animations for testing
	config.move_anim_duration = 0.001
	config.capture_anim_duration = 0.001
	config.multi_capture_gap = 0.001
	_ui.configure(_board, config)


func _clear_board() -> void:
	for row: int in _board.board_size:
		for col: int in _board.board_size:
			_board._grid[row][col] = _board.PieceType.NONE
	_board._king_pos = Vector2i(-1, -1)
	_ui._pieces.clear()


func _place_piece(pos: Vector2i, piece_type: int) -> void:
	_board._grid[pos.x][pos.y] = piece_type
	_ui._pieces[pos] = piece_type
	if piece_type == _board.PieceType.KING:
		_board._king_pos = pos
		_ui._king_pos = pos


func _set_active_side(side: int) -> void:
	_board._active_side = side
	_ui._active_side = side


# ---------------------------------------------------------------------------
# Selection — tap friendly piece
# ---------------------------------------------------------------------------

func test_select_player_piece() -> void:
	_setup(_board.Side.DEFENDER)
	# Defender pieces are at (3,2) in standard layout
	_ui.select_piece(Vector2i(3, 2))

	assert_bool(_ui.has_selection()).is_true()
	assert_object(_ui.get_selected_cell()).is_equal(Vector2i(3, 2))


func test_select_piece_populates_legal_moves() -> void:
	_setup(_board.Side.DEFENDER)
	# (2,2) has moves to (1,2) and (2,1) in starting position
	_ui.select_piece(Vector2i(2, 2))

	var moves: Array = _ui.get_legal_moves()
	assert_bool(moves.size() > 0).is_true()


func test_cannot_select_opponent_piece() -> void:
	_setup(_board.Side.DEFENDER)
	# Attackers are at (0, 3) in standard layout — should not be selectable
	_ui.select_piece(Vector2i(0, 3))

	assert_bool(_ui.has_selection()).is_false()


func test_cannot_select_empty_cell() -> void:
	_setup(_board.Side.DEFENDER)
	_ui.select_piece(Vector2i(0, 0))  # Corner — empty

	assert_bool(_ui.has_selection()).is_false()


func test_select_king_as_defender() -> void:
	_setup(_board.Side.DEFENDER)
	# King is at (3,3)
	_ui.select_piece(Vector2i(3, 3))

	assert_bool(_ui.has_selection()).is_true()
	assert_object(_ui.get_selected_cell()).is_equal(Vector2i(3, 3))


# ---------------------------------------------------------------------------
# Deselection
# ---------------------------------------------------------------------------

func test_deselect_clears_selection() -> void:
	_setup(_board.Side.DEFENDER)
	_ui.select_piece(Vector2i(3, 2))
	_ui.deselect_piece()

	assert_bool(_ui.has_selection()).is_false()
	assert_int(_ui.get_legal_moves().size()).is_equal(0)


func test_tap_selected_piece_deselects() -> void:
	_setup(_board.Side.DEFENDER)
	_set_active_side(_board.Side.DEFENDER)
	_ui.select_piece(Vector2i(3, 2))
	# Tap the same piece again
	_ui._handle_tap(Vector2i(3, 2))

	assert_bool(_ui.has_selection()).is_false()


func test_tap_empty_deselects() -> void:
	_setup(_board.Side.DEFENDER)
	_set_active_side(_board.Side.DEFENDER)
	_ui.select_piece(Vector2i(3, 2))
	# Tap empty cell
	_ui._handle_tap(Vector2i(0, 0))

	assert_bool(_ui.has_selection()).is_false()


func test_tap_outside_board_deselects() -> void:
	_setup(_board.Side.DEFENDER)
	_set_active_side(_board.Side.DEFENDER)
	_ui.select_piece(Vector2i(3, 2))
	# Tap outside board
	_ui._handle_tap(Vector2i(-1, -1))

	assert_bool(_ui.has_selection()).is_false()


# ---------------------------------------------------------------------------
# Switch selection
# ---------------------------------------------------------------------------

func test_tap_different_friendly_piece_switches() -> void:
	_setup(_board.Side.DEFENDER)
	_set_active_side(_board.Side.DEFENDER)
	_ui.select_piece(Vector2i(3, 2))
	# Tap a different defender
	_ui._handle_tap(Vector2i(3, 4))

	assert_bool(_ui.has_selection()).is_true()
	assert_object(_ui.get_selected_cell()).is_equal(Vector2i(3, 4))


# ---------------------------------------------------------------------------
# Move submission
# ---------------------------------------------------------------------------

func test_tap_legal_destination_submits_move() -> void:
	_setup(_board.Side.ATTACKER)
	_clear_board()
	_place_piece(Vector2i(1, 1), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(6, 6), _board.PieceType.KING)
	_set_active_side(_board.Side.ATTACKER)

	_ui.select_piece(Vector2i(1, 1))

	var moves: Array = _ui.get_legal_moves()
	assert_bool(moves.size() > 0).is_true()
	if moves.size() == 0:
		return

	var dest: Vector2i = moves[0]
	_ui._handle_tap(dest)

	# Selection should be cleared after move
	assert_bool(_ui.has_selection()).is_false()


func test_move_sets_animating() -> void:
	_setup(_board.Side.ATTACKER)
	_clear_board()
	_place_piece(Vector2i(1, 1), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(6, 6), _board.PieceType.KING)
	_set_active_side(_board.Side.ATTACKER)

	_ui.select_piece(Vector2i(1, 1))

	var moves: Array = _ui.get_legal_moves()
	if moves.size() > 0:
		_ui._handle_tap(moves[0])
		# Should be animating immediately after move
		assert_bool(_ui.is_animating()).is_true()


# ---------------------------------------------------------------------------
# Input blocking during animation
# ---------------------------------------------------------------------------

func test_input_blocked_during_animation() -> void:
	_setup(_board.Side.DEFENDER)
	_ui._animating = true
	# Try to select — should be blocked
	_ui._handle_tap(Vector2i(3, 2))

	assert_bool(_ui.has_selection()).is_false()


func test_input_blocked_on_opponent_turn() -> void:
	_setup(_board.Side.DEFENDER)
	_set_active_side(_board.Side.ATTACKER)
	# Player is defender but it's attacker's turn
	_ui._handle_tap(Vector2i(3, 2))

	assert_bool(_ui.has_selection()).is_false()


# ---------------------------------------------------------------------------
# Player side detection
# ---------------------------------------------------------------------------

func test_attacker_player_can_select_attackers() -> void:
	_setup(_board.Side.ATTACKER)
	_set_active_side(_board.Side.ATTACKER)
	# Attacker at (1, 3) — has legal moves to (1,2) and (1,4)
	_ui.select_piece(Vector2i(1, 3))

	assert_bool(_ui.has_selection()).is_true()


func test_attacker_player_cannot_select_defenders() -> void:
	_setup(_board.Side.ATTACKER)
	_set_active_side(_board.Side.ATTACKER)
	# Defender at (3, 2) — not selectable as attacker player
	_ui.select_piece(Vector2i(3, 2))

	assert_bool(_ui.has_selection()).is_false()


# ---------------------------------------------------------------------------
# Animation state
# ---------------------------------------------------------------------------

func test_animation_state_defaults() -> void:
	_setup(_board.Side.DEFENDER)
	assert_bool(_ui.is_animating()).is_false()
	assert_bool(_ui._moving_piece_active).is_false()
	assert_bool(_ui._capturing_active).is_false()


func test_piece_moved_signal_starts_animation() -> void:
	_setup(_board.Side.DEFENDER)
	_board.piece_moved.emit(_board.PieceType.ATTACKER, Vector2i(0, 3), Vector2i(0, 2))

	assert_bool(_ui.is_animating()).is_true()
	assert_bool(_ui._moving_piece_active).is_true()


func test_piece_captured_queues_capture() -> void:
	_setup(_board.Side.DEFENDER)
	_board.piece_captured.emit(_board.PieceType.DEFENDER, Vector2i(2, 2), Vector2i(2, 1))

	assert_int(_ui._capture_queue.size()).is_equal(1)


# ---------------------------------------------------------------------------
# Capture move detection
# ---------------------------------------------------------------------------

func test_capture_move_detected() -> void:
	_setup(_board.Side.ATTACKER)
	_clear_board()

	# Set up a capture scenario:
	# Attacker at (3,0) — left flank
	# Defender at (3,1) — target
	# Attacker at (2,2) — can move to (3,2) to capture
	_place_piece(Vector2i(3, 0), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(3, 1), _board.PieceType.DEFENDER)
	_place_piece(Vector2i(2, 2), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(6, 6), _board.PieceType.KING)
	_set_active_side(_board.Side.ATTACKER)

	_ui.select_piece(Vector2i(2, 2))

	# (3,2) should be in capture moves
	var found_capture: bool = false
	for dest: Vector2i in _ui._capture_moves:
		if dest == Vector2i(3, 2):
			found_capture = true
	assert_bool(found_capture).is_true()


# ---------------------------------------------------------------------------
# King escape detection
# ---------------------------------------------------------------------------

func test_king_escape_move_detected() -> void:
	_setup(_board.Side.DEFENDER)
	_clear_board()

	# King one step from corner
	_place_piece(Vector2i(0, 1), _board.PieceType.KING)
	_place_piece(Vector2i(5, 5), _board.PieceType.ATTACKER)
	_set_active_side(_board.Side.DEFENDER)

	_ui.select_piece(Vector2i(0, 1))

	# (0,0) should be in king escape moves
	var found_escape: bool = false
	for dest: Vector2i in _ui._king_escape_moves:
		if dest == Vector2i(0, 0):
			found_escape = true
	assert_bool(found_escape).is_true()


# ---------------------------------------------------------------------------
# Last move highlight updated after move
# ---------------------------------------------------------------------------

func test_last_move_updated_after_signal() -> void:
	_setup(_board.Side.DEFENDER)
	_board.piece_moved.emit(_board.PieceType.ATTACKER, Vector2i(0, 3), Vector2i(0, 1))

	assert_object(_ui._last_move.from).is_equal(Vector2i(0, 3))
	assert_object(_ui._last_move.to).is_equal(Vector2i(0, 1))
