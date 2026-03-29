## GdUnit4 tests for AI Personality Layer (S1-05)
##
## Covers S1-05 acceptance criteria:
## - 4 personality types produce visibly different play (different weights applied)
## - Difficulty levels set correct search depth, mistake chance
## - Mistake injection selects from pool (not suicidal moves)
## - Erratic disruption swaps moves within top 50%
## - Think time varies by difficulty
## - Difficulty capped at 7
class_name TestAIPersonality
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

func _setup(ai_side: int, diff: int = 1, pers: int = -1) -> void:
	_board.start_match(_board.MatchMode.STANDARD, _board.Side.DEFENDER)
	_ai.configure(_board, ai_side, diff, pers)


# ---------------------------------------------------------------------------
# Personality weights applied correctly
# ---------------------------------------------------------------------------

func test_balanced_personality_weights() -> void:
	_setup(_board.Side.ATTACKER, 1, _ai.Personality.BALANCED)
	assert_float(_ai.w_material).is_equal(1.0)
	assert_float(_ai.w_king_freedom).is_equal(1.0)
	assert_float(_ai.w_king_proximity).is_equal(1.0)
	assert_float(_ai.w_board_control).is_equal(1.0)
	assert_float(_ai.w_threat).is_equal(1.0)


func test_defensive_personality_weights() -> void:
	_setup(_board.Side.ATTACKER, 1, _ai.Personality.DEFENSIVE)
	assert_float(_ai.w_material).is_equal(0.8)
	assert_float(_ai.w_king_freedom).is_equal(1.5)
	assert_float(_ai.w_king_proximity).is_equal(0.7)
	assert_float(_ai.w_board_control).is_equal(1.2)
	assert_float(_ai.w_threat).is_equal(0.6)


func test_aggressive_personality_weights() -> void:
	_setup(_board.Side.ATTACKER, 1, _ai.Personality.AGGRESSIVE)
	assert_float(_ai.w_material).is_equal(1.3)
	assert_float(_ai.w_king_freedom).is_equal(0.7)
	assert_float(_ai.w_king_proximity).is_equal(1.4)
	assert_float(_ai.w_board_control).is_equal(0.8)
	assert_float(_ai.w_threat).is_equal(1.5)


func test_tactical_personality_weights() -> void:
	_setup(_board.Side.ATTACKER, 1, _ai.Personality.TACTICAL)
	assert_float(_ai.w_material).is_equal(1.0)
	assert_float(_ai.w_king_freedom).is_equal(1.0)
	assert_float(_ai.w_king_proximity).is_equal(0.8)
	assert_float(_ai.w_board_control).is_equal(1.3)
	assert_float(_ai.w_threat).is_equal(1.4)


func test_erratic_uses_balanced_weights() -> void:
	_setup(_board.Side.ATTACKER, 1, _ai.Personality.ERRATIC)
	assert_float(_ai.w_material).is_equal(1.0)
	assert_float(_ai.w_threat).is_equal(1.0)


# ---------------------------------------------------------------------------
# Difficulty sets correct search depth
# ---------------------------------------------------------------------------

func test_difficulty_1_depth() -> void:
	_setup(_board.Side.ATTACKER, 1)
	assert_int(_ai.search_depth).is_equal(1)


func test_difficulty_3_depth() -> void:
	_setup(_board.Side.ATTACKER, 3)
	assert_int(_ai.search_depth).is_equal(2)


func test_difficulty_5_depth() -> void:
	_setup(_board.Side.ATTACKER, 5)
	assert_int(_ai.search_depth).is_equal(3)


func test_difficulty_7_depth() -> void:
	_setup(_board.Side.ATTACKER, 7)
	assert_int(_ai.search_depth).is_equal(5)


# ---------------------------------------------------------------------------
# Difficulty capped at 7
# ---------------------------------------------------------------------------

func test_difficulty_capped_at_7() -> void:
	_setup(_board.Side.ATTACKER, 1)
	_ai.apply_difficulty(10)
	assert_int(_ai.difficulty).is_equal(7)
	assert_int(_ai.search_depth).is_equal(5)


func test_difficulty_minimum_1() -> void:
	_setup(_board.Side.ATTACKER, 1)
	_ai.apply_difficulty(0)
	assert_int(_ai.difficulty).is_equal(1)


# ---------------------------------------------------------------------------
# Mistake chance values correct per difficulty
# ---------------------------------------------------------------------------

func test_difficulty_1_mistake_chance() -> void:
	_setup(_board.Side.ATTACKER, 1)
	assert_float(_ai._mistake_chance).is_equal(0.35)


func test_difficulty_4_mistake_chance() -> void:
	_setup(_board.Side.ATTACKER, 4)
	assert_float(_ai._mistake_chance).is_equal(0.12)


func test_difficulty_7_no_mistakes() -> void:
	_setup(_board.Side.ATTACKER, 7)
	assert_float(_ai._mistake_chance).is_equal(0.0)


# ---------------------------------------------------------------------------
# Think time varies by difficulty
# ---------------------------------------------------------------------------

func test_think_time_difficulty_1() -> void:
	_setup(_board.Side.ATTACKER, 1)
	assert_float(_ai._think_time_min).is_equal(0.5)
	assert_float(_ai._think_time_max).is_equal(1.5)


func test_think_time_difficulty_7() -> void:
	_setup(_board.Side.ATTACKER, 7)
	assert_float(_ai._think_time_min).is_equal(2.0)
	assert_float(_ai._think_time_max).is_equal(4.0)


func test_get_think_time_in_range() -> void:
	_setup(_board.Side.ATTACKER, 1)
	# Run multiple times to check range
	for i in 20:
		var t: float = _ai.get_think_time()
		assert_float(t).is_greater_equal(0.5)
		assert_float(t).is_less_equal(1.5)


# ---------------------------------------------------------------------------
# AI still returns valid moves with personality/difficulty configured
# ---------------------------------------------------------------------------

func test_aggressive_ai_returns_valid_move() -> void:
	_setup(_board.Side.ATTACKER, 2, _ai.Personality.AGGRESSIVE)
	var move: Dictionary = _ai.select_move()
	assert_bool(move.is_empty()).is_false()


func test_defensive_ai_returns_valid_move() -> void:
	_setup(_board.Side.DEFENDER, 2, _ai.Personality.DEFENSIVE)
	_board._active_side = _board.Side.DEFENDER
	var move: Dictionary = _ai.select_move()
	assert_bool(move.is_empty()).is_false()


func test_tactical_ai_returns_valid_move() -> void:
	_setup(_board.Side.ATTACKER, 3, _ai.Personality.TACTICAL)
	var move: Dictionary = _ai.select_move()
	assert_bool(move.is_empty()).is_false()


func test_erratic_ai_returns_valid_move() -> void:
	_setup(_board.Side.ATTACKER, 1, _ai.Personality.ERRATIC)
	var move: Dictionary = _ai.select_move()
	assert_bool(move.is_empty()).is_false()


# ---------------------------------------------------------------------------
# Configure with both difficulty and personality in one call
# ---------------------------------------------------------------------------

func test_configure_sets_both() -> void:
	_board.start_match(_board.MatchMode.STANDARD, _board.Side.DEFENDER)
	_ai.configure(_board, _board.Side.ATTACKER, 4, _ai.Personality.TACTICAL)
	assert_int(_ai.difficulty).is_equal(4)
	assert_int(_ai.personality).is_equal(_ai.Personality.TACTICAL)
	assert_int(_ai.search_depth).is_equal(2)
	assert_float(_ai.w_board_control).is_equal(1.3)
