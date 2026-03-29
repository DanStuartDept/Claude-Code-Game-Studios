## GdUnit4 tests for BoardLayout Resource and its integration with BoardRules.
##
## Verifies:
## - BoardLayout resource loads from .tres
## - apply_layout() copies all fields to the engine
## - start_match() uses layout when assigned
## - Custom layouts produce different board configurations
## - No hardcoded values remain in the engine after layout is applied
##
## Task: S1-02 (Board Rules Resources)
class_name TestBoardLayout
extends GdUnitTestSuite


const BoardRulesScript := preload("res://src/core/board_rules.gd")
const BoardLayoutScript := preload("res://src/data/board_layout.gd")

var _board: Node


func before_test() -> void:
	_board = BoardRulesScript.new()
	add_child(_board)


func after_test() -> void:
	_board.queue_free()


# --- Helpers ---

## Create a minimal custom layout for testing non-default configurations.
func _make_small_layout() -> Resource:
	var layout := BoardLayoutScript.new()
	layout.board_size = 5
	layout.throne_pos = Vector2i(2, 2)
	layout.corner_positions = [
		Vector2i(0, 0), Vector2i(0, 4), Vector2i(4, 0), Vector2i(4, 4)
	] as Array[Vector2i]
	layout.attacker_start_positions = [
		Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),
		Vector2i(1, 2),
		Vector2i(3, 2),
		Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3),
	] as Array[Vector2i]
	layout.defender_start_positions = [
		Vector2i(2, 1), Vector2i(2, 3),
		Vector2i(1, 1), Vector2i(3, 3),
	] as Array[Vector2i]
	layout.king_start_pos = Vector2i(2, 2)
	layout.king_threatened_threshold = 3
	layout.king_capture_sides = 4
	return layout


# ---------------------------------------------------------------------------
# Test: Default .tres file loads and has correct values
# ---------------------------------------------------------------------------

func test_default_layout_loads_from_tres() -> void:
	var layout: Resource = load("res://assets/data/board/default_layout.tres")
	assert_object(layout).is_not_null()
	assert_int(layout.board_size).is_equal(7)
	assert_object(layout.throne_pos).is_equal(Vector2i(3, 3))
	assert_int(layout.corner_positions.size()).is_equal(4)
	assert_int(layout.attacker_start_positions.size()).is_equal(16)
	assert_int(layout.defender_start_positions.size()).is_equal(8)
	assert_object(layout.king_start_pos).is_equal(Vector2i(3, 3))
	assert_int(layout.king_threatened_threshold).is_equal(2)
	assert_int(layout.king_capture_sides).is_equal(4)


# ---------------------------------------------------------------------------
# Test: apply_layout() copies all fields to the engine
# ---------------------------------------------------------------------------

func test_apply_layout_copies_all_fields() -> void:
	var layout := _make_small_layout()
	_board.apply_layout(layout)

	assert_int(_board.board_size).is_equal(5)
	assert_object(_board.throne_pos).is_equal(Vector2i(2, 2))
	assert_int(_board.corner_positions.size()).is_equal(4)
	assert_object(_board.corner_positions[1]).is_equal(Vector2i(0, 4))
	assert_int(_board.attacker_start_positions.size()).is_equal(8)
	assert_int(_board.defender_start_positions.size()).is_equal(4)
	assert_object(_board.king_start_pos).is_equal(Vector2i(2, 2))
	assert_int(_board.king_threatened_threshold).is_equal(3)
	assert_int(_board.king_capture_sides).is_equal(4)


# ---------------------------------------------------------------------------
# Test: start_match() uses layout when assigned
# ---------------------------------------------------------------------------

func test_start_match_uses_layout() -> void:
	var layout := _make_small_layout()
	_board.layout = layout
	_board.start_match(_board.MatchMode.STANDARD, _board.Side.DEFENDER)

	# Board should be 5x5
	assert_int(_board.board_size).is_equal(5)

	# Pieces should match layout counts
	assert_int(_board.get_piece_count(_board.Side.ATTACKER)).is_equal(8)
	assert_int(_board.get_piece_count(_board.Side.DEFENDER)).is_equal(5)  # 4 defenders + 1 king

	# King should be on the custom throne position
	assert_int(_board.get_piece(Vector2i(2, 2))).is_equal(_board.PieceType.KING)

	# Positions outside 5x5 should be out of bounds
	assert_bool(_board.is_in_bounds(Vector2i(4, 4))).is_true()
	assert_bool(_board.is_in_bounds(Vector2i(5, 0))).is_false()


# ---------------------------------------------------------------------------
# Test: Default layout produces identical board to hardcoded defaults
# ---------------------------------------------------------------------------

func test_default_layout_matches_hardcoded_defaults() -> void:
	# Start match WITHOUT layout (uses inline defaults)
	_board.start_match(_board.MatchMode.STANDARD, _board.Side.DEFENDER)
	var state_without_layout: Dictionary = _board.get_board_state()

	# Start match WITH default layout
	var layout: Resource = load("res://assets/data/board/default_layout.tres")
	_board.apply_layout(layout)
	_board.start_match(_board.MatchMode.STANDARD, _board.Side.DEFENDER)
	var state_with_layout: Dictionary = _board.get_board_state()

	# Grids should be identical
	for row in 7:
		for col in 7:
			assert_int(state_with_layout.grid[row][col]).is_equal(
				state_without_layout.grid[row][col]
			)


# ---------------------------------------------------------------------------
# Test: Layout arrays are duplicated (not shared references)
# ---------------------------------------------------------------------------

func test_layout_arrays_are_duplicated() -> void:
	var layout := _make_small_layout()
	_board.apply_layout(layout)

	# Mutating the engine's array should NOT affect the layout resource
	_board.corner_positions.append(Vector2i(9, 9))
	assert_int(layout.corner_positions.size()).is_equal(4)
	assert_int(_board.corner_positions.size()).is_equal(5)


# ---------------------------------------------------------------------------
# Test: Custom layout with different tuning knobs works in gameplay
# ---------------------------------------------------------------------------

func test_custom_layout_tuning_affects_gameplay() -> void:
	var layout := _make_small_layout()
	layout.king_threatened_threshold = 1  # Threat fires at just 1 adjacent attacker
	_board.apply_layout(layout)
	_board.start_match(_board.MatchMode.STANDARD, _board.Side.DEFENDER)

	# Clear and set up a scenario: king with 1 adjacent attacker
	for row in _board.board_size:
		for col in _board.board_size:
			_board._grid[row][col] = _board.PieceType.NONE

	_board._grid[2][2] = _board.PieceType.KING
	_board._king_pos = Vector2i(2, 2)
	_board._grid[1][2] = _board.PieceType.ATTACKER
	# Need a defender so the side has legal moves after attacker moves
	_board._grid[4][4] = _board.PieceType.DEFENDER
	# Attacker to move and create the threat check
	_board._grid[3][0] = _board.PieceType.ATTACKER
	_board._active_side = _board.Side.ATTACKER

	var threat_data := []
	_board.king_threatened.connect(func(kp: Vector2i, tc: int) -> void:
		threat_data.append({"pos": kp, "count": tc})
	)

	# Move attacker to (3,2) — king at (2,2) now has 1 adjacent attacker at (1,2)
	# plus the moved attacker at (3,2) = 2 threats. But threshold is 1, so even
	# 1 would trigger. The signal check happens after captures/turn switch.
	_board.submit_move(Vector2i(3, 0), Vector2i(3, 2))

	# With threshold=1, king_threatened should have fired
	assert_int(threat_data.size()).is_equal(1)


# ---------------------------------------------------------------------------
# Test: No hardcoded values — engine fields match layout after apply
# ---------------------------------------------------------------------------

func test_no_hardcoded_values_remain() -> void:
	var layout := BoardLayoutScript.new()
	# Set every field to a non-default value
	layout.board_size = 9
	layout.throne_pos = Vector2i(4, 4)
	layout.corner_positions = [
		Vector2i(0, 0), Vector2i(0, 8), Vector2i(8, 0), Vector2i(8, 8)
	] as Array[Vector2i]
	layout.attacker_start_positions = [Vector2i(0, 4)] as Array[Vector2i]
	layout.defender_start_positions = [Vector2i(4, 3)] as Array[Vector2i]
	layout.king_start_pos = Vector2i(4, 4)
	layout.king_threatened_threshold = 3
	layout.king_capture_sides = 3

	_board.apply_layout(layout)

	# Every engine field should reflect the layout, not the old defaults
	assert_int(_board.board_size).is_equal(9)
	assert_object(_board.throne_pos).is_equal(Vector2i(4, 4))
	assert_int(_board.corner_positions.size()).is_equal(4)
	assert_object(_board.corner_positions[1]).is_equal(Vector2i(0, 8))
	assert_int(_board.attacker_start_positions.size()).is_equal(1)
	assert_int(_board.defender_start_positions.size()).is_equal(1)
	assert_object(_board.king_start_pos).is_equal(Vector2i(4, 4))
	assert_int(_board.king_threatened_threshold).is_equal(3)
	assert_int(_board.king_capture_sides).is_equal(3)
