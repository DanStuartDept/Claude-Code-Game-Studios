## GdUnit4 tests for Tutorial System
## Covers data loading, step progression, input constraints, scripted AI moves,
## narrator text flow, and completion signal.
##
## See: design/gdd/tutorial-system.md, assets/data/tutorial/tutorial_steps.json
class_name TestTutorialSystem
extends GdUnitTestSuite


const TutorialScript := preload("res://src/core/tutorial_system.gd")

var _ts: Node


func before_test() -> void:
	_ts = TutorialScript.new()
	add_child(_ts)
	# Data loads automatically via _ready() -> _load_data()


func after_test() -> void:
	_ts.queue_free()


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

func test_tutorial_data_loads_steps() -> void:
	assert_bool(_ts._steps.is_empty()).is_false()
	assert_int(_ts._steps.size()).is_equal(8)


func test_tutorial_data_loads_board_layout() -> void:
	assert_bool(_ts._board_layout.is_empty()).is_false()
	assert_bool(_ts._board_layout.has("king")).is_true()
	assert_bool(_ts._board_layout.has("defenders")).is_true()
	assert_bool(_ts._board_layout.has("attackers")).is_true()


func test_tutorial_board_layout_piece_counts() -> void:
	var defenders: Array = _ts._board_layout.get("defenders", [])
	var attackers: Array = _ts._board_layout.get("attackers", [])
	assert_int(defenders.size()).is_equal(5)
	assert_int(attackers.size()).is_equal(8)


func test_tutorial_board_layout_board_size() -> void:
	var board_size: int = _ts._board_layout.get("boardSize", 0)
	assert_int(board_size).is_equal(7)


# ---------------------------------------------------------------------------
# Step data structure
# ---------------------------------------------------------------------------

func test_tutorial_step_1_is_introduction() -> void:
	var step: Dictionary = _ts._steps[0]
	assert_str(step.get("concept", "")).is_equal("introduction")
	assert_bool(step.get("playerAction") == null).is_true()
	assert_bool(step.get("aiAction") == null).is_true()
	assert_bool(step.get("narratorText", "") != "").is_true()


func test_tutorial_step_2_has_player_and_ai_action() -> void:
	var step: Dictionary = _ts._steps[1]
	assert_str(step.get("concept", "")).is_equal("movement")
	assert_bool(step.get("playerAction") != null).is_true()
	assert_bool(step.get("aiAction") != null).is_true()


func test_tutorial_step_5_has_ai_only_action() -> void:
	var step: Dictionary = _ts._steps[4]
	assert_str(step.get("concept", "")).is_equal("being_captured")
	assert_bool(step.get("playerAction") == null).is_true()
	assert_bool(step.get("aiAction") != null).is_true()
	assert_str(step.get("narratorTextAfter", "")).is_equal("Like that.")


func test_tutorial_step_8_is_victory() -> void:
	var step: Dictionary = _ts._steps[7]
	assert_str(step.get("concept", "")).is_equal("victory")
	assert_bool(step.get("playerAction") == null).is_true()
	assert_bool(step.get("aiAction") == null).is_true()


func test_tutorial_all_steps_have_narrator_text() -> void:
	for i: int in _ts._steps.size():
		var step: Dictionary = _ts._steps[i]
		var text: String = step.get("narratorText", "")
		assert_bool(text != "").is_true()


func test_tutorial_all_steps_have_narrator_text_key() -> void:
	for i: int in _ts._steps.size():
		var step: Dictionary = _ts._steps[i]
		var key: String = step.get("narratorTextKey", "")
		assert_bool(key != "").is_true()


# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------

func test_tutorial_initially_inactive() -> void:
	assert_bool(_ts.is_active()).is_false()


func test_tutorial_initial_step_is_zero() -> void:
	assert_int(_ts._current_step).is_equal(0)


# ---------------------------------------------------------------------------
# Player action constraints
# ---------------------------------------------------------------------------

func test_tutorial_player_actions_have_allowed_pieces() -> void:
	for step: Dictionary in _ts._steps:
		var action: Variant = step.get("playerAction")
		if action != null and action is Dictionary:
			var allowed: Array = action.get("allowedPieces", [])
			assert_bool(allowed.size() > 0).is_true()


func test_tutorial_player_actions_have_forced_highlights() -> void:
	for step: Dictionary in _ts._steps:
		var action: Variant = step.get("playerAction")
		if action != null and action is Dictionary:
			var highlights: Array = action.get("forcedHighlights", [])
			assert_bool(highlights.size() > 0).is_true()


func test_tutorial_player_actions_have_expected_move() -> void:
	for step: Dictionary in _ts._steps:
		var action: Variant = step.get("playerAction")
		if action != null and action is Dictionary:
			var expected: Variant = action.get("expectedMove")
			assert_bool(expected != null and expected is Dictionary).is_true()


# ---------------------------------------------------------------------------
# AI action data
# ---------------------------------------------------------------------------

func test_tutorial_ai_actions_have_from_and_to() -> void:
	for step: Dictionary in _ts._steps:
		var action: Variant = step.get("aiAction")
		if action != null and action is Dictionary:
			var from_arr: Array = action.get("from", [])
			var to_arr: Array = action.get("to", [])
			assert_int(from_arr.size()).is_equal(2)
			assert_int(to_arr.size()).is_equal(2)


# ---------------------------------------------------------------------------
# Completion signal
# ---------------------------------------------------------------------------

func test_tutorial_complete_signal_exists() -> void:
	assert_bool(_ts.has_signal("tutorial_complete")).is_true()
