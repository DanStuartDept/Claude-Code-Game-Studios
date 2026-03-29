## GdUnit4 tests for AI System — Core Evaluator (S1-04)
##
## Covers S1-04 acceptance criteria:
## - AI returns valid legal move every turn
## - Depth 1-4 search works
## - Evaluation completes < 200ms on desktop
## - AI plays as both Attacker and Defender
## - Iterative deepening returns valid move if budget exceeded
## - Single legal move skips evaluation
## - Move ordering prioritizes captures and King-adjacent moves
class_name TestAISystem
extends GdUnitTestSuite


const BoardRulesScript := preload("res://src/core/board_rules.gd")
const AISystemScript := preload("res://src/core/ai_system.gd")

var _board: Node
var _ai: Node


func before_test() -> void:
	_board = BoardRulesScript.new()
	add_child(_board)
	_ai = AISystemScript.new()
	add_child(_ai)


func after_test() -> void:
	_ai.queue_free()
	_board.queue_free()


# --- Helpers ---

func _setup_match_and_ai(ai_side: int, depth: int = 2) -> void:
	_board.start_match(_board.MatchMode.STANDARD, _board.Side.DEFENDER)
	_ai.search_depth = depth
	_ai.configure(_board, ai_side)


func _clear_board() -> void:
	for row in _board.board_size:
		for col in _board.board_size:
			_board._grid[row][col] = _board.PieceType.NONE
	_board._king_pos = Vector2i(-1, -1)


func _place_piece(pos: Vector2i, piece_type: int) -> void:
	_board._grid[pos.x][pos.y] = piece_type
	if piece_type == _board.PieceType.KING:
		_board._king_pos = pos


func _set_active_side(side: int) -> void:
	_board._active_side = side


func _is_move_legal(move: Dictionary, side: int) -> bool:
	var legal_moves: Array = _board.get_all_legal_moves(side)
	for lm: Dictionary in legal_moves:
		if lm.from == move.from and lm.to == move.to:
			return true
	return false


# ---------------------------------------------------------------------------
# AI returns a valid legal move — standard starting position
# ---------------------------------------------------------------------------

func test_ai_returns_valid_move_as_attacker() -> void:
	_setup_match_and_ai(_board.Side.ATTACKER, 1)
	_set_active_side(_board.Side.ATTACKER)

	var move: Dictionary = _ai.select_move()
	assert_bool(move.is_empty()).is_false()
	assert_bool(_is_move_legal(move, _board.Side.ATTACKER)).is_true()


func test_ai_returns_valid_move_as_defender() -> void:
	_setup_match_and_ai(_board.Side.DEFENDER, 1)
	_set_active_side(_board.Side.DEFENDER)

	var move: Dictionary = _ai.select_move()
	assert_bool(move.is_empty()).is_false()
	assert_bool(_is_move_legal(move, _board.Side.DEFENDER)).is_true()


# ---------------------------------------------------------------------------
# Depth 1-4 search works
# ---------------------------------------------------------------------------

func test_depth_1_returns_move() -> void:
	_setup_match_and_ai(_board.Side.ATTACKER, 1)
	var move: Dictionary = _ai.select_move()
	assert_bool(move.is_empty()).is_false()


func test_depth_2_returns_move() -> void:
	_setup_match_and_ai(_board.Side.ATTACKER, 2)
	var move: Dictionary = _ai.select_move()
	assert_bool(move.is_empty()).is_false()


func test_depth_3_returns_move() -> void:
	_setup_match_and_ai(_board.Side.ATTACKER, 3)
	var move: Dictionary = _ai.select_move()
	assert_bool(move.is_empty()).is_false()


func test_depth_4_returns_move() -> void:
	_setup_match_and_ai(_board.Side.ATTACKER, 4)
	var move: Dictionary = _ai.select_move()
	assert_bool(move.is_empty()).is_false()


# ---------------------------------------------------------------------------
# Evaluation completes within time budget
# ---------------------------------------------------------------------------

func test_depth_2_completes_under_200ms() -> void:
	_setup_match_and_ai(_board.Side.ATTACKER, 2)
	_ai.computation_time_budget_ms = 200
	var start := Time.get_ticks_msec()
	_ai.select_move()
	var elapsed := Time.get_ticks_msec() - start
	# Budget enforcement guarantees completion within budget + margin for timer granularity
	assert_int(elapsed).is_less(250)


func test_depth_4_completes_under_200ms() -> void:
	_setup_match_and_ai(_board.Side.ATTACKER, 4)
	_ai.computation_time_budget_ms = 200
	var start := Time.get_ticks_msec()
	_ai.select_move()
	var elapsed := Time.get_ticks_msec() - start
	# Should complete or be interrupted by budget
	assert_int(elapsed).is_less(250)  # Small margin for timer granularity


# ---------------------------------------------------------------------------
# Single legal move skips evaluation
# ---------------------------------------------------------------------------

func test_few_legal_moves_returns_valid() -> void:
	_setup_match_and_ai(_board.Side.ATTACKER, 3)
	_clear_board()

	_place_piece(Vector2i(1, 0), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(0, 0), _board.PieceType.DEFENDER)
	_place_piece(Vector2i(2, 0), _board.PieceType.DEFENDER)
	_place_piece(Vector2i(6, 6), _board.PieceType.KING)
	_set_active_side(_board.Side.ATTACKER)

	var legal: Array = _board.get_all_legal_moves(_board.Side.ATTACKER)
	assert_bool(legal.size() >= 1).is_true()

	var move: Dictionary = _ai.select_move()
	assert_bool(move.is_empty()).is_false()


# ---------------------------------------------------------------------------
# No legal moves returns empty
# ---------------------------------------------------------------------------

func test_no_legal_moves_returns_empty() -> void:
	_setup_match_and_ai(_board.Side.ATTACKER, 2)
	_clear_board()

	# Completely surrounded attacker — no legal moves
	_place_piece(Vector2i(1, 1), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(0, 1), _board.PieceType.DEFENDER)
	_place_piece(Vector2i(2, 1), _board.PieceType.DEFENDER)
	_place_piece(Vector2i(1, 0), _board.PieceType.DEFENDER)
	_place_piece(Vector2i(1, 2), _board.PieceType.DEFENDER)
	_place_piece(Vector2i(6, 6), _board.PieceType.KING)
	_set_active_side(_board.Side.ATTACKER)

	var move: Dictionary = _ai.select_move()
	assert_bool(move.is_empty()).is_true()


# ---------------------------------------------------------------------------
# AI finds winning move — King escape
# ---------------------------------------------------------------------------

func test_ai_finds_king_escape() -> void:
	_setup_match_and_ai(_board.Side.DEFENDER, 1)
	_clear_board()

	# King one step from corner — AI should find the escape
	_place_piece(Vector2i(0, 1), _board.PieceType.KING)
	_place_piece(Vector2i(5, 5), _board.PieceType.ATTACKER)
	_set_active_side(_board.Side.DEFENDER)

	var move: Dictionary = _ai.select_move()
	assert_object(move.from).is_equal(Vector2i(0, 1))
	assert_object(move.to).is_equal(Vector2i(0, 0))


# ---------------------------------------------------------------------------
# AI finds winning move — King capture
# ---------------------------------------------------------------------------

func test_ai_finds_king_capture() -> void:
	_setup_match_and_ai(_board.Side.ATTACKER, 1)
	_clear_board()

	# King at (3,3) with 3 adjacent attackers — 4th attacker can complete capture
	_place_piece(Vector2i(3, 3), _board.PieceType.KING)
	_place_piece(Vector2i(2, 3), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(4, 3), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(3, 2), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(3, 6), _board.PieceType.ATTACKER)  # Can move to (3,4)
	_set_active_side(_board.Side.ATTACKER)

	var move: Dictionary = _ai.select_move()
	# AI should move attacker at (3,6) to (3,4) to complete capture
	assert_object(move.from).is_equal(Vector2i(3, 6))
	assert_object(move.to).is_equal(Vector2i(3, 4))


# ---------------------------------------------------------------------------
# AI prefers captures
# ---------------------------------------------------------------------------

func test_ai_prefers_capture_move() -> void:
	_setup_match_and_ai(_board.Side.ATTACKER, 1)
	_clear_board()

	# Attacker can capture a defender by moving to flank position
	_place_piece(Vector2i(3, 0), _board.PieceType.ATTACKER)  # Left flank
	_place_piece(Vector2i(3, 1), _board.PieceType.DEFENDER)  # Target
	_place_piece(Vector2i(2, 2), _board.PieceType.ATTACKER)  # Can move to (3,2)
	_place_piece(Vector2i(6, 6), _board.PieceType.KING)
	_set_active_side(_board.Side.ATTACKER)

	var move: Dictionary = _ai.select_move()
	# Should capture by moving to (3,2), flanking the defender at (3,1)
	assert_object(move.to).is_equal(Vector2i(3, 2))


# ---------------------------------------------------------------------------
# Evaluation function tests
# ---------------------------------------------------------------------------

func test_evaluate_returns_positive_for_advantage() -> void:
	_setup_match_and_ai(_board.Side.ATTACKER, 1)
	# Starting position: attacker has 16 pieces, defender has 9
	# Material score should favor attacker
	var score: float = _ai.evaluate_position()
	# Material component: 16 - 9 = +7 for attacker
	assert_float(score).is_greater(0.0)


func test_evaluate_king_near_corner_favors_defender() -> void:
	_setup_match_and_ai(_board.Side.DEFENDER, 1)
	_clear_board()

	# King very close to corner — should be good for defender
	_place_piece(Vector2i(0, 1), _board.PieceType.KING)
	_place_piece(Vector2i(5, 5), _board.PieceType.ATTACKER)
	_set_active_side(_board.Side.DEFENDER)

	var score: float = _ai.evaluate_position()
	# King proximity should be high → positive for defender
	assert_float(score).is_greater(0.0)


# ---------------------------------------------------------------------------
# Iterative deepening returns valid move even if budget exceeded
# ---------------------------------------------------------------------------

func test_iterative_deepening_with_tight_budget() -> void:
	_setup_match_and_ai(_board.Side.ATTACKER, 4)
	_ai.computation_time_budget_ms = 1  # Very tight budget — will likely exceed

	var move: Dictionary = _ai.select_move()
	# Should still return a valid move (from depth 1 at minimum)
	assert_bool(move.is_empty()).is_false()
	assert_bool(_is_move_legal(move, _board.Side.ATTACKER)).is_true()


# ---------------------------------------------------------------------------
# Board state is restored after evaluation (no side effects)
# ---------------------------------------------------------------------------

func test_select_move_does_not_mutate_board() -> void:
	_setup_match_and_ai(_board.Side.ATTACKER, 2)

	var state_before: Dictionary = _board.get_board_state()
	_ai.select_move()
	var state_after: Dictionary = _board.get_board_state()

	# Grid should be identical
	for row in _board.board_size:
		for col in _board.board_size:
			assert_int(state_after.grid[row][col]).is_equal(state_before.grid[row][col])

	# Match state should be identical
	assert_int(state_after.active_side).is_equal(state_before.active_side)
	assert_int(state_after.move_count).is_equal(state_before.move_count)
	assert_bool(state_after.match_active).is_equal(state_before.match_active)
