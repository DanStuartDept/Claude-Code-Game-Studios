## GdUnit4 tests for Board Rules Engine
## Covers all 19 acceptance criteria from design/gdd/board-rules-engine.md
##
## Test naming: test_<criterion_number>_<description>
## See plan for criterion-to-test mapping.
class_name TestBoardRules
extends GdUnitTestSuite


const BoardRulesScript := preload("res://src/core/board_rules.gd")

var _board: Node


func before_test() -> void:
	_board = BoardRulesScript.new()
	add_child(_board)
	_board.start_match(_board.MatchMode.STANDARD, _board.Side.DEFENDER)


func after_test() -> void:
	_board.queue_free()


# --- Helpers ---

## Clear the entire board grid for custom test setups.
func _clear_board() -> void:
	for row in _board.board_size:
		for col in _board.board_size:
			_board._grid[row][col] = _board.PieceType.NONE
	_board._king_pos = Vector2i(-1, -1)


## Place a single piece on the board.
func _place_piece(pos: Vector2i, piece_type: int) -> void:
	_board._grid[pos.x][pos.y] = piece_type
	if piece_type == _board.PieceType.KING:
		_board._king_pos = pos


## Force the active side for testing.
func _set_active_side(side: int) -> void:
	_board._active_side = side


# ---------------------------------------------------------------------------
# AC-1: Board initializes with correct starting layout
# ---------------------------------------------------------------------------

func test_01_starting_layout() -> void:
	# 16 attackers
	assert_int(_board.get_piece_count(_board.Side.ATTACKER)).is_equal(16)

	# 8 defenders + 1 king = 9 pieces on the defender side
	assert_int(_board.get_piece_count(_board.Side.DEFENDER)).is_equal(9)

	# King is on the throne
	assert_int(_board.get_piece(Vector2i(3, 3))).is_equal(_board.PieceType.KING)

	# Verify a few specific attacker positions
	assert_int(_board.get_piece(Vector2i(0, 2))).is_equal(_board.PieceType.ATTACKER)
	assert_int(_board.get_piece(Vector2i(3, 0))).is_equal(_board.PieceType.ATTACKER)

	# Verify a few specific defender positions
	assert_int(_board.get_piece(Vector2i(2, 2))).is_equal(_board.PieceType.DEFENDER)
	assert_int(_board.get_piece(Vector2i(4, 3))).is_equal(_board.PieceType.DEFENDER)

	# Empty corners
	assert_int(_board.get_piece(Vector2i(0, 0))).is_equal(_board.PieceType.NONE)
	assert_int(_board.get_piece(Vector2i(6, 6))).is_equal(_board.PieceType.NONE)


# ---------------------------------------------------------------------------
# AC-2: Pieces move orthogonally, blocked by other pieces and board edges
# ---------------------------------------------------------------------------

func test_02_orthogonal_movement_and_blocking() -> void:
	_clear_board()
	_place_piece(Vector2i(3, 3), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(3, 5), _board.PieceType.DEFENDER)
	_set_active_side(_board.Side.ATTACKER)

	var moves: Array = _board.get_legal_moves(Vector2i(3, 3))

	# Can move left to column 0 (3 squares), right to column 4 only (blocked by defender at 5)
	# Can move up to row 0 (3 squares), down to row 6 (3 squares)
	# Total: 3 left + 1 right + 3 up + 3 down = 10
	assert_int(moves.size()).is_equal(10)

	# Blocked: cannot reach (3, 5) or beyond
	assert_bool(Vector2i(3, 5) in moves).is_false()
	assert_bool(Vector2i(3, 6) in moves).is_false()

	# Reachable
	assert_bool(Vector2i(3, 4) in moves).is_true()
	assert_bool(Vector2i(0, 3) in moves).is_true()
	assert_bool(Vector2i(6, 3) in moves).is_true()


# ---------------------------------------------------------------------------
# AC-3: Non-King pieces cannot enter Throne or Corner tiles
# ---------------------------------------------------------------------------

func test_03_restricted_tiles_for_non_king() -> void:
	_clear_board()
	# Attacker on row 0, col 1 — moving left would reach corner (0,0)
	_place_piece(Vector2i(0, 1), _board.PieceType.ATTACKER)
	_set_active_side(_board.Side.ATTACKER)

	var moves: Array = _board.get_legal_moves(Vector2i(0, 1))
	assert_bool(Vector2i(0, 0) in moves).is_false()

	# Defender near throne — cannot enter (3,3)
	_place_piece(Vector2i(3, 1), _board.PieceType.DEFENDER)
	_set_active_side(_board.Side.DEFENDER)

	var def_moves: Array = _board.get_legal_moves(Vector2i(3, 1))
	assert_bool(Vector2i(3, 3) in def_moves).is_false()
	# But can reach (3, 2)
	assert_bool(Vector2i(3, 2) in def_moves).is_true()


# ---------------------------------------------------------------------------
# AC-4: King can enter Throne and all four Corner tiles
# ---------------------------------------------------------------------------

func test_04_king_enters_throne_and_corners() -> void:
	_clear_board()
	_place_piece(Vector2i(3, 0), _board.PieceType.KING)
	_set_active_side(_board.Side.DEFENDER)

	var moves: Array = _board.get_legal_moves(Vector2i(3, 0))
	# King can reach throne at (3,3)
	assert_bool(Vector2i(3, 3) in moves).is_true()

	# King near a corner
	_clear_board()
	_place_piece(Vector2i(0, 1), _board.PieceType.KING)
	_set_active_side(_board.Side.DEFENDER)

	moves = _board.get_legal_moves(Vector2i(0, 1))
	assert_bool(Vector2i(0, 0) in moves).is_true()  # corner


# ---------------------------------------------------------------------------
# AC-5: Custodial capture works
# ---------------------------------------------------------------------------

func test_05_custodial_capture() -> void:
	_clear_board()
	# Attacker at (3,0), Defender at (3,1). Attacker at (2,2) moves down to (3,2)
	# to flank the defender. (Can't approach from (3,4) — throne at (3,3) blocks.)
	_place_piece(Vector2i(3, 0), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(3, 1), _board.PieceType.DEFENDER)
	_place_piece(Vector2i(6, 6), _board.PieceType.KING)
	_place_piece(Vector2i(2, 2), _board.PieceType.ATTACKER)
	_set_active_side(_board.Side.ATTACKER)

	var result: Dictionary = _board.submit_move(Vector2i(2, 2), Vector2i(3, 2))
	assert_bool(result.valid).is_true()
	var caps: Array = result.captures
	assert_int(caps.size()).is_equal(1)
	assert_object(caps[0]).is_equal(Vector2i(3, 1))
	# Defender should be removed
	assert_int(_board.get_piece(Vector2i(3, 1))).is_equal(_board.PieceType.NONE)


# ---------------------------------------------------------------------------
# AC-6: Voluntary entry into sandwich does NOT trigger capture
# ---------------------------------------------------------------------------

func test_06_voluntary_sandwich_no_capture() -> void:
	_clear_board()
	# Attacker at (1,0) and (1,2). Defender moves from (0,1) into (1,1) —
	# the defender is between two attackers. The defender should NOT be captured
	# because capture is active: the sandwiching side must be the one that moved.
	_place_piece(Vector2i(1, 0), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(1, 2), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(0, 1), _board.PieceType.DEFENDER)
	_place_piece(Vector2i(5, 5), _board.PieceType.KING)
	_set_active_side(_board.Side.DEFENDER)

	var result: Dictionary = _board.submit_move(Vector2i(0, 1), Vector2i(1, 1))
	assert_bool(result.valid).is_true()
	# Defender moved into the sandwich — it should NOT be captured
	assert_int(_board.get_piece(Vector2i(1, 1))).is_equal(_board.PieceType.DEFENDER)
	# No captures of enemy pieces either (no flanking setup from defender's perspective)
	var caps: Array = result.captures
	assert_int(caps.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-7: Multi-capture on different axes
# ---------------------------------------------------------------------------

func test_07_multi_capture() -> void:
	_clear_board()
	# Attacker moves from (2,2) down to (3,2), capturing on two axes:
	# Horizontal: defender at (3,1) flanked by attacker at (3,0) and moved attacker at (3,2)
	# Vertical: defender at (4,2) flanked by attacker at (5,2) and moved attacker at (3,2)
	_place_piece(Vector2i(3, 0), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(3, 1), _board.PieceType.DEFENDER)
	_place_piece(Vector2i(5, 2), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(4, 2), _board.PieceType.DEFENDER)
	_place_piece(Vector2i(6, 6), _board.PieceType.KING)
	_place_piece(Vector2i(2, 2), _board.PieceType.ATTACKER)
	_set_active_side(_board.Side.ATTACKER)

	var result: Dictionary = _board.submit_move(Vector2i(2, 2), Vector2i(3, 2))
	assert_bool(result.valid).is_true()
	var caps: Array = result.captures
	assert_int(caps.size()).is_equal(2)
	assert_bool(Vector2i(3, 1) in caps).is_true()
	assert_bool(Vector2i(4, 2) in caps).is_true()


# ---------------------------------------------------------------------------
# AC-8: Corner tiles and empty Throne act as hostile for capture
# ---------------------------------------------------------------------------

func test_08_hostile_tiles_for_capture() -> void:
	# Corner as hostile: defender at (0,1), attacker moves to (0,2) —
	# corner (0,0) flanks the defender
	_clear_board()
	_place_piece(Vector2i(0, 1), _board.PieceType.DEFENDER)
	_place_piece(Vector2i(0, 4), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(6, 6), _board.PieceType.KING)
	_set_active_side(_board.Side.ATTACKER)

	var result: Dictionary = _board.submit_move(Vector2i(0, 4), Vector2i(0, 2))
	assert_bool(result.valid).is_true()
	var caps: Array = result.captures
	assert_int(caps.size()).is_equal(1)
	assert_object(caps[0]).is_equal(Vector2i(0, 1))

	# Empty throne as hostile: attacker at (3,4) next to empty throne (3,3).
	# Defender moves from (2,5) to (3,5) to flank attacker against the throne.
	_clear_board()
	_place_piece(Vector2i(3, 4), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(2, 5), _board.PieceType.DEFENDER)
	_place_piece(Vector2i(6, 6), _board.PieceType.KING)
	_set_active_side(_board.Side.DEFENDER)

	result = _board.submit_move(Vector2i(2, 5), Vector2i(3, 5))
	assert_bool(result.valid).is_true()
	caps = result.captures
	assert_int(caps.size()).is_equal(1)
	assert_object(caps[0]).is_equal(Vector2i(3, 4))


# ---------------------------------------------------------------------------
# AC-9: King requires 4-sided enclosure to capture
# ---------------------------------------------------------------------------

func test_09_king_four_sided_capture() -> void:
	_clear_board()
	# King at (3,3), attackers on 3 sides — NOT captured
	_place_piece(Vector2i(3, 3), _board.PieceType.KING)
	_place_piece(Vector2i(2, 3), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(4, 3), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(3, 2), _board.PieceType.ATTACKER)
	# Attacker moves to 4th side to complete capture
	_place_piece(Vector2i(3, 6), _board.PieceType.ATTACKER)
	_set_active_side(_board.Side.ATTACKER)

	var result: Dictionary = _board.submit_move(Vector2i(3, 6), Vector2i(3, 4))
	assert_bool(result.valid).is_true()
	assert_int(result.win).is_equal(_board.WinReason.KING_CAPTURED)
	assert_bool(_board.is_match_active()).is_false()


# ---------------------------------------------------------------------------
# AC-10: King on Throne NOT captured at 3 sides
# ---------------------------------------------------------------------------

func test_10_king_on_throne_not_captured_at_three_sides() -> void:
	_clear_board()
	# King on throne (3,3), attackers on 3 sides
	_place_piece(Vector2i(3, 3), _board.PieceType.KING)
	_place_piece(Vector2i(2, 3), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(4, 3), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(3, 2), _board.PieceType.ATTACKER)
	# Move an attacker near the 4th side but NOT to it
	_place_piece(Vector2i(3, 6), _board.PieceType.ATTACKER)
	_set_active_side(_board.Side.ATTACKER)

	# Move attacker to (3,5) — NOT completing the enclosure
	var result: Dictionary = _board.submit_move(Vector2i(3, 6), Vector2i(3, 5))
	assert_bool(result.valid).is_true()
	# King should NOT be captured — only 3 sides surrounded, throne is occupied by king
	assert_int(result.win).is_equal(_board.WinReason.NONE)
	assert_bool(_board.is_match_active()).is_true()


# ---------------------------------------------------------------------------
# AC-11: Defender wins when King reaches any corner
# ---------------------------------------------------------------------------

func test_11_king_escape_to_corner() -> void:
	_clear_board()
	_place_piece(Vector2i(0, 1), _board.PieceType.KING)
	# Need at least one attacker so the match is valid
	_place_piece(Vector2i(5, 5), _board.PieceType.ATTACKER)
	_set_active_side(_board.Side.DEFENDER)

	var result: Dictionary = _board.submit_move(Vector2i(0, 1), Vector2i(0, 0))
	assert_bool(result.valid).is_true()
	assert_int(result.win).is_equal(_board.WinReason.KING_ESCAPED)
	assert_bool(_board.is_match_active()).is_false()


# ---------------------------------------------------------------------------
# AC-12: Attacker wins when King is fully surrounded
# ---------------------------------------------------------------------------

func test_12_king_fully_surrounded() -> void:
	_clear_board()
	_place_piece(Vector2i(4, 4), _board.PieceType.KING)
	_place_piece(Vector2i(3, 4), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(5, 4), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(4, 3), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(4, 6), _board.PieceType.ATTACKER)
	_set_active_side(_board.Side.ATTACKER)

	var result: Dictionary = _board.submit_move(Vector2i(4, 6), Vector2i(4, 5))
	assert_bool(result.valid).is_true()
	assert_int(result.win).is_equal(_board.WinReason.KING_CAPTURED)


# ---------------------------------------------------------------------------
# AC-13: No legal moves = loss for that side
# ---------------------------------------------------------------------------

func test_13_no_legal_moves_loss() -> void:
	_clear_board()
	# Single attacker in corner-adjacent, blocked on all sides
	_place_piece(Vector2i(0, 1), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(0, 0), _board.PieceType.KING)
	_place_piece(Vector2i(0, 2), _board.PieceType.DEFENDER)
	_place_piece(Vector2i(1, 1), _board.PieceType.DEFENDER)

	# Defender at (2,1) moves to create the block, after which attacker has no moves
	_place_piece(Vector2i(2, 1), _board.PieceType.DEFENDER)
	_set_active_side(_board.Side.DEFENDER)

	# Defender moves from (2,1) to (2,0) — now (0,1) attacker is completely blocked:
	# left is king at (0,0), right is defender at (0,2), down is defender at (1,1)
	# up is board edge
	var result: Dictionary = _board.submit_move(Vector2i(2, 1), Vector2i(2, 0))
	assert_bool(result.valid).is_true()
	# Attacker has no legal moves — defender wins
	assert_int(result.win).is_equal(_board.WinReason.NO_LEGAL_MOVES)
	assert_bool(_board.is_match_active()).is_false()


# ---------------------------------------------------------------------------
# AC-14: Win condition halts game immediately
# ---------------------------------------------------------------------------

func test_14_win_halts_game() -> void:
	_clear_board()
	_place_piece(Vector2i(0, 1), _board.PieceType.KING)
	_place_piece(Vector2i(5, 5), _board.PieceType.ATTACKER)
	_set_active_side(_board.Side.DEFENDER)

	# King escapes to corner
	_board.submit_move(Vector2i(0, 1), Vector2i(0, 0))
	assert_bool(_board.is_match_active()).is_false()

	# Further moves should be rejected
	var result: Dictionary = _board.submit_move(Vector2i(5, 5), Vector2i(5, 4))
	assert_bool(result.valid).is_false()
	assert_str(result.error).is_equal("No active match")


# ---------------------------------------------------------------------------
# AC-15: get_legal_moves() returns correct moves for various board states
# ---------------------------------------------------------------------------

func test_15_legal_moves_correctness() -> void:
	# Empty board with one piece — should have maximum movement
	_clear_board()
	_place_piece(Vector2i(3, 3), _board.PieceType.ATTACKER)
	_set_active_side(_board.Side.ATTACKER)

	var moves: Array = _board.get_legal_moves(Vector2i(3, 3))
	# From center of 7x7: piece is ON the throne (leaving is fine, restriction is on landing)
	# Left: (3,2), (3,1), (3,0) → 3 moves
	# Right: (3,4), (3,5), (3,6) → 3 moves (3,6 is NOT a corner — corners are at 0,0/0,6/6,0/6,6)
	# Up: (2,3), (1,3), (0,3) → 3 moves
	# Down: (4,3), (5,3), (6,3) → 3 moves
	# Total: 3 + 3 + 3 + 3 = 12
	assert_int(moves.size()).is_equal(12)

	# Piece in corner-adjacent with no blockers
	_clear_board()
	_place_piece(Vector2i(0, 1), _board.PieceType.DEFENDER)

	moves = _board.get_legal_moves(Vector2i(0, 1))
	# Right: (0,2)...(0,5) — (0,6) is corner, stop → 4 moves
	# Left: (0,0) is corner, stop → 0 moves
	# Down: (1,1)...(6,1) → 6 moves
	# Up: board edge → 0 moves
	# Total: 4 + 0 + 6 + 0 = 10
	assert_int(moves.size()).is_equal(10)


# ---------------------------------------------------------------------------
# AC-16: All 5 signals emit with correct data
# ---------------------------------------------------------------------------

func test_16_signals_emit_correctly() -> void:
	_clear_board()
	_place_piece(Vector2i(3, 0), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(3, 1), _board.PieceType.DEFENDER)
	# Approach from above to avoid throne at (3,3) blocking horizontal movement
	_place_piece(Vector2i(2, 2), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(6, 6), _board.PieceType.KING)
	_set_active_side(_board.Side.ATTACKER)

	# Track signal emissions
	var moved_data := []
	var captured_data := []
	var turn_data := []

	_board.piece_moved.connect(func(pt: int, fp: Vector2i, tp: Vector2i) -> void:
		moved_data.append({"piece": pt, "from": fp, "to": tp})
	)
	_board.piece_captured.connect(func(pt: int, pos: Vector2i, by: Vector2i) -> void:
		captured_data.append({"piece": pt, "pos": pos, "by": by})
	)
	_board.turn_changed.connect(func(side: int) -> void:
		turn_data.append(side)
	)

	# Attacker moves from (2,2) to (3,2) — flanking defender at (3,1) with attacker at (3,0)
	_board.submit_move(Vector2i(2, 2), Vector2i(3, 2))

	# piece_moved should have fired
	assert_int(moved_data.size()).is_equal(1)
	assert_int(moved_data[0].piece).is_equal(_board.PieceType.ATTACKER)
	assert_object(moved_data[0].from).is_equal(Vector2i(2, 2))
	assert_object(moved_data[0].to).is_equal(Vector2i(3, 2))

	# piece_captured should have fired
	assert_int(captured_data.size()).is_equal(1)
	assert_int(captured_data[0].piece).is_equal(_board.PieceType.DEFENDER)
	assert_object(captured_data[0].pos).is_equal(Vector2i(3, 1))
	assert_object(captured_data[0].by).is_equal(Vector2i(3, 2))

	# turn_changed should have fired
	assert_int(turn_data.size()).is_equal(1)
	assert_int(turn_data[0]).is_equal(_board.Side.DEFENDER)


func test_16b_match_ended_signal() -> void:
	_clear_board()
	_place_piece(Vector2i(0, 1), _board.PieceType.KING)
	_place_piece(Vector2i(5, 5), _board.PieceType.ATTACKER)
	_set_active_side(_board.Side.DEFENDER)

	var ended_data := []
	_board.match_ended.connect(func(result: Dictionary) -> void:
		ended_data.append(result)
	)

	_board.submit_move(Vector2i(0, 1), Vector2i(0, 0))

	assert_int(ended_data.size()).is_equal(1)
	assert_int(ended_data[0].winner).is_equal(_board.Side.DEFENDER)
	assert_int(ended_data[0].reason).is_equal(_board.WinReason.KING_ESCAPED)


func test_16c_king_threatened_signal() -> void:
	_clear_board()
	_place_piece(Vector2i(3, 3), _board.PieceType.KING)
	_place_piece(Vector2i(2, 3), _board.PieceType.ATTACKER)
	# Attacker moves next to king to create 2 threats
	_place_piece(Vector2i(4, 5), _board.PieceType.ATTACKER)
	_set_active_side(_board.Side.ATTACKER)

	var threat_data := []
	_board.king_threatened.connect(func(kp: Vector2i, tc: int) -> void:
		threat_data.append({"pos": kp, "count": tc})
	)

	_board.submit_move(Vector2i(4, 5), Vector2i(4, 3))

	assert_int(threat_data.size()).is_equal(1)
	assert_int(threat_data[0].count).is_equal(2)


# ---------------------------------------------------------------------------
# AC-17: Scripted mode skips gameplay and emits predetermined result
# ---------------------------------------------------------------------------

func test_17_scripted_mode() -> void:
	_board.start_match(_board.MatchMode.SCRIPTED, _board.Side.DEFENDER)

	# Moves should be rejected in scripted mode
	var result: Dictionary = _board.submit_move(Vector2i(0, 2), Vector2i(0, 1))
	assert_bool(result.valid).is_false()
	assert_str(result.error).is_equal("Cannot submit moves in scripted mode")

	# Resolve with predetermined result
	var ended_data := []
	_board.match_ended.connect(func(r: Dictionary) -> void:
		ended_data.append(r)
	)

	_board.resolve_scripted_match(_board.Side.ATTACKER, _board.WinReason.KING_CAPTURED)

	assert_bool(_board.is_match_active()).is_false()
	assert_int(ended_data.size()).is_equal(1)
	assert_int(ended_data[0].winner).is_equal(_board.Side.ATTACKER)
	assert_int(ended_data[0].reason).is_equal(_board.WinReason.KING_CAPTURED)


# ---------------------------------------------------------------------------
# AC-18: Side assignment works for both player-as-attacker and player-as-defender
# ---------------------------------------------------------------------------

func test_18_side_assignment() -> void:
	# Player as defender (default)
	_board.start_match(_board.MatchMode.STANDARD, _board.Side.DEFENDER)
	assert_int(_board.get_player_side()).is_equal(_board.Side.DEFENDER)

	# Player as attacker
	_board.start_match(_board.MatchMode.STANDARD, _board.Side.ATTACKER)
	assert_int(_board.get_player_side()).is_equal(_board.Side.ATTACKER)

	# Attacker always moves first regardless of player side
	assert_int(_board.get_active_side()).is_equal(_board.Side.ATTACKER)


# ---------------------------------------------------------------------------
# AC-19: No hardcoded values — all constants as class-level variables
# ---------------------------------------------------------------------------

func test_19_data_externalized() -> void:
	# Board configuration is accessible as class-level variables, not constants
	assert_int(_board.board_size).is_equal(7)
	assert_object(_board.throne_pos).is_equal(Vector2i(3, 3))
	assert_int(_board.corner_positions.size()).is_equal(4)
	assert_int(_board.attacker_start_positions.size()).is_equal(16)
	assert_int(_board.defender_start_positions.size()).is_equal(8)
	assert_object(_board.king_start_pos).is_equal(Vector2i(3, 3))
	assert_int(_board.king_threatened_threshold).is_equal(2)
	assert_int(_board.king_capture_sides).is_equal(4)

	# Verify these are writable (can be overridden by Resource in S1-02)
	_board.king_threatened_threshold = 3
	assert_int(_board.king_threatened_threshold).is_equal(3)


# ---------------------------------------------------------------------------
# Additional coverage: Public API methods not covered by acceptance criteria
# ---------------------------------------------------------------------------

func test_get_tile_type_returns_correct_types() -> void:
	assert_int(_board.get_tile_type(Vector2i(3, 3))).is_equal(_board.TileType.THRONE)
	assert_int(_board.get_tile_type(Vector2i(0, 0))).is_equal(_board.TileType.CORNER)
	assert_int(_board.get_tile_type(Vector2i(0, 6))).is_equal(_board.TileType.CORNER)
	assert_int(_board.get_tile_type(Vector2i(6, 0))).is_equal(_board.TileType.CORNER)
	assert_int(_board.get_tile_type(Vector2i(6, 6))).is_equal(_board.TileType.CORNER)
	assert_int(_board.get_tile_type(Vector2i(2, 2))).is_equal(_board.TileType.NORMAL)


func test_is_in_bounds_returns_correct_values() -> void:
	assert_bool(_board.is_in_bounds(Vector2i(0, 0))).is_true()
	assert_bool(_board.is_in_bounds(Vector2i(6, 6))).is_true()
	assert_bool(_board.is_in_bounds(Vector2i(3, 3))).is_true()
	assert_bool(_board.is_in_bounds(Vector2i(-1, 0))).is_false()
	assert_bool(_board.is_in_bounds(Vector2i(0, -1))).is_false()
	assert_bool(_board.is_in_bounds(Vector2i(7, 0))).is_false()
	assert_bool(_board.is_in_bounds(Vector2i(0, 7))).is_false()


func test_get_all_legal_moves_returns_moves_for_side() -> void:
	_clear_board()
	_place_piece(Vector2i(0, 1), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(6, 6), _board.PieceType.KING)

	var attacker_moves: Array = _board.get_all_legal_moves(_board.Side.ATTACKER)
	# Single attacker at (0,1) — has multiple destinations
	assert_bool(attacker_moves.size() > 0).is_true()
	# All moves should originate from (0,1)
	for m in attacker_moves:
		assert_object(m.from).is_equal(Vector2i(0, 1))

	var defender_moves: Array = _board.get_all_legal_moves(_board.Side.DEFENDER)
	# King at (6,6) is a corner — king can enter corners, so it has moves out
	assert_bool(defender_moves.size() > 0).is_true()
	for m in defender_moves:
		assert_object(m.from).is_equal(Vector2i(6, 6))


func test_get_board_state_returns_complete_snapshot() -> void:
	var state: Dictionary = _board.get_board_state()

	assert_bool(state.has("grid")).is_true()
	assert_bool(state.has("active_side")).is_true()
	assert_bool(state.has("winner")).is_true()
	assert_bool(state.has("win_reason")).is_true()
	assert_bool(state.has("match_active")).is_true()
	assert_bool(state.has("match_mode")).is_true()
	assert_bool(state.has("player_side")).is_true()
	assert_bool(state.has("king_pos")).is_true()
	assert_bool(state.has("move_count")).is_true()

	# Grid should be 7x7
	assert_int(state.grid.size()).is_equal(7)
	assert_int(state.grid[0].size()).is_equal(7)

	# State reflects current match
	assert_bool(state.match_active).is_true()
	assert_int(state.active_side).is_equal(_board.Side.ATTACKER)
	assert_int(state.player_side).is_equal(_board.Side.DEFENDER)
	assert_int(state.match_mode).is_equal(_board.MatchMode.STANDARD)
	assert_int(state.move_count).is_equal(0)


func test_get_king_threat_count_returns_adjacent_attackers() -> void:
	_clear_board()
	_place_piece(Vector2i(3, 3), _board.PieceType.KING)
	assert_int(_board.get_king_threat_count()).is_equal(0)

	_place_piece(Vector2i(2, 3), _board.PieceType.ATTACKER)
	assert_int(_board.get_king_threat_count()).is_equal(1)

	_place_piece(Vector2i(4, 3), _board.PieceType.ATTACKER)
	assert_int(_board.get_king_threat_count()).is_equal(2)

	# Diagonal attacker should NOT count
	_place_piece(Vector2i(2, 2), _board.PieceType.ATTACKER)
	assert_int(_board.get_king_threat_count()).is_equal(2)


func test_get_match_mode_returns_current_mode() -> void:
	assert_int(_board.get_match_mode()).is_equal(_board.MatchMode.STANDARD)

	_board.start_match(_board.MatchMode.SCRIPTED, _board.Side.DEFENDER)
	assert_int(_board.get_match_mode()).is_equal(_board.MatchMode.SCRIPTED)


func test_get_move_count_increments_on_valid_moves() -> void:
	assert_int(_board.get_move_count()).is_equal(0)

	_clear_board()
	_place_piece(Vector2i(0, 1), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(6, 6), _board.PieceType.KING)
	_set_active_side(_board.Side.ATTACKER)

	_board.submit_move(Vector2i(0, 1), Vector2i(0, 2))
	assert_int(_board.get_move_count()).is_equal(1)

	_set_active_side(_board.Side.DEFENDER)
	_board.submit_move(Vector2i(6, 6), Vector2i(6, 5))
	assert_int(_board.get_move_count()).is_equal(2)


func test_get_piece_out_of_bounds_returns_none() -> void:
	assert_int(_board.get_piece(Vector2i(-1, 0))).is_equal(_board.PieceType.NONE)
	assert_int(_board.get_piece(Vector2i(7, 3))).is_equal(_board.PieceType.NONE)
	assert_int(_board.get_piece(Vector2i(3, -1))).is_equal(_board.PieceType.NONE)


func test_submit_move_rejects_no_piece_at_source() -> void:
	_clear_board()
	_place_piece(Vector2i(6, 6), _board.PieceType.KING)
	_set_active_side(_board.Side.ATTACKER)

	var result: Dictionary = _board.submit_move(Vector2i(0, 0), Vector2i(0, 1))
	assert_bool(result.valid).is_false()
	assert_str(result.error).is_equal("No piece at source")


func test_submit_move_rejects_wrong_side_piece() -> void:
	_clear_board()
	_place_piece(Vector2i(3, 0), _board.PieceType.DEFENDER)
	_place_piece(Vector2i(6, 6), _board.PieceType.KING)
	_set_active_side(_board.Side.ATTACKER)

	var result: Dictionary = _board.submit_move(Vector2i(3, 0), Vector2i(3, 1))
	assert_bool(result.valid).is_false()
	assert_str(result.error).is_equal("Piece belongs to other side")


func test_submit_move_rejects_illegal_destination() -> void:
	_clear_board()
	_place_piece(Vector2i(0, 1), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(6, 6), _board.PieceType.KING)
	_set_active_side(_board.Side.ATTACKER)

	# Diagonal move is illegal
	var result: Dictionary = _board.submit_move(Vector2i(0, 1), Vector2i(1, 2))
	assert_bool(result.valid).is_false()
	assert_str(result.error).is_equal("Illegal move")
