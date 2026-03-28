# PROTOTYPE - NOT FOR PRODUCTION
# Question: Do Fidchell board rules produce correct gameplay?
# Date: 2026-03-28
#
# Run this scene in Godot. It prints PASS/FAIL for every test case.
# Attach this script to a Node in a scene, or run via command line:
#   godot --headless --script test_board_rules.gd

extends SceneTree

const BoardRulesScript = preload("res://board_rules.gd")

var pass_count := 0
var fail_count := 0
var current_test := ""


func _init() -> void:
	run_all_tests()
	print("\n========================================")
	print("Results: %d passed, %d failed, %d total" % [pass_count, fail_count, pass_count + fail_count])
	if fail_count == 0:
		print("ALL TESTS PASSED")
	else:
		print("FAILURES DETECTED")
	print("========================================")
	quit()


# --- Test Runner ---

func run_all_tests() -> void:
	print("=== Fidchell Board Rules — Prototype Test Suite ===\n")

	# Setup tests
	test_initial_board_layout()
	test_piece_counts()

	# Movement tests
	test_basic_orthogonal_movement()
	test_movement_blocked_by_piece()
	test_non_king_cannot_enter_throne()
	test_non_king_cannot_enter_corner()
	test_king_can_enter_throne()
	test_king_can_enter_corner()

	# Capture tests
	test_basic_custodial_capture()
	test_voluntary_sandwich_no_capture()
	test_multi_capture()
	test_corner_as_hostile_for_capture()
	test_empty_throne_as_hostile_for_capture()
	test_king_not_captured_by_sandwich()

	# King capture tests
	test_king_captured_four_sides()
	test_king_not_captured_three_sides()
	test_king_on_throne_not_captured_three_sides()
	test_king_three_attackers_plus_hostile_tile()
	test_king_three_attackers_one_defender_no_capture()

	# Win condition tests
	test_king_escapes_to_corner()
	test_king_escape_priority_over_capture()
	test_no_legal_moves_loses()

	# Turn order tests
	test_attacker_moves_first()
	test_turns_alternate()

	# Misc tests
	test_all_defenders_captured_king_survives()
	test_king_threat_count()
	test_legal_move_generation_completeness()


# --- Helpers ---

func begin(name: String) -> void:
	current_test = name


func assert_true(condition: bool, message: String = "") -> void:
	if condition:
		pass_count += 1
		print("  PASS: %s — %s" % [current_test, message])
	else:
		fail_count += 1
		print("  FAIL: %s — %s" % [current_test, message])


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual == expected:
		pass_count += 1
		print("  PASS: %s — %s" % [current_test, message])
	else:
		fail_count += 1
		print("  FAIL: %s — %s (expected %s, got %s)" % [current_test, message, str(expected), str(actual)])


func fresh_board() -> BoardRulesScript:
	var b := BoardRulesScript.new()
	b.start_match()
	return b


func empty_board() -> BoardRulesScript:
	# Returns a board with match active but no pieces — for custom setups
	var b := BoardRulesScript.new()
	b.match_active = true
	b.active_side = BoardRulesScript.Side.ATTACKER
	b.win_reason = BoardRulesScript.WinReason.NONE
	b.winner = -1
	b.move_count = 0
	return b


func place(b: BoardRulesScript, pos: Vector2i, piece: BoardRulesScript.PieceType) -> void:
	b.grid[pos.x][pos.y] = piece
	if piece == BoardRulesScript.PieceType.KING:
		b.king_pos = pos


# --- Setup Tests ---

func test_initial_board_layout() -> void:
	begin("Initial board layout")
	var b := fresh_board()
	assert_eq(b.get_piece(Vector2i(3, 3)), BoardRulesScript.PieceType.KING, "King on throne")
	assert_eq(b.get_piece(Vector2i(0, 3)), BoardRulesScript.PieceType.ATTACKER, "Attacker at (0,3)")
	assert_eq(b.get_piece(Vector2i(2, 2)), BoardRulesScript.PieceType.DEFENDER, "Defender at (2,2)")
	assert_eq(b.get_piece(Vector2i(0, 0)), BoardRulesScript.PieceType.NONE, "Corner empty at start")


func test_piece_counts() -> void:
	begin("Piece counts")
	var b := fresh_board()
	assert_eq(b.get_piece_count(BoardRulesScript.Side.ATTACKER), 16, "16 attackers")
	assert_eq(b.get_piece_count(BoardRulesScript.Side.DEFENDER), 9, "9 defenders (8 + king)")


# --- Movement Tests ---

func test_basic_orthogonal_movement() -> void:
	begin("Basic orthogonal movement")
	var b := empty_board()
	place(b, Vector2i(3, 3), BoardRulesScript.PieceType.KING)
	place(b, Vector2i(0, 0), BoardRulesScript.PieceType.ATTACKER)
	b.active_side = BoardRulesScript.Side.ATTACKER

	var moves := b.get_legal_moves_for_piece(Vector2i(0, 0))
	# Attacker at corner (0,0) — corner is restricted for non-king
	# Actually attacker is AT (0,0) which is a corner. Let me use a different position.
	# Let me place attacker at (0,1) instead
	b.grid[0][0] = BoardRulesScript.PieceType.NONE
	place(b, Vector2i(0, 1), BoardRulesScript.PieceType.ATTACKER)

	moves = b.get_legal_moves_for_piece(Vector2i(0, 1))
	# Can move right along row 0: (0,2) through (0,5) — (0,6) is corner, blocked
	# Can move left: nothing (0,0 is corner, blocked)
	# Can move down: (1,1) through (6,1) — 6 cells, but (3,3) is throne which is col 3 not 1
	# So down: (1,1), (2,1), (3,1)... wait, king is at (3,3), not blocking col 1
	# Down: (1,1), (2,1), (3,1), (4,1), (5,1), (6,1) = 6 squares
	# Right: (0,2), (0,3), (0,4), (0,5) = 4 squares (0,6 is corner = restricted)
	# Left: (0,0) is corner = restricted, so 0 squares
	# Up: already at row 0, so 0 squares
	# Total: 10 moves
	assert_eq(moves.size(), 10, "Attacker at (0,1) has 10 legal moves")


func test_movement_blocked_by_piece() -> void:
	begin("Movement blocked by piece")
	var b := empty_board()
	place(b, Vector2i(3, 0), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(3, 3), BoardRulesScript.PieceType.KING)
	b.active_side = BoardRulesScript.Side.ATTACKER

	var moves := b.get_legal_moves_for_piece(Vector2i(3, 0))
	# Right: (3,1), (3,2) — blocked by king at (3,3)
	# Left: nothing — board edge
	# Up: (2,0), (1,0), (0,0) — but (0,0) is corner, restricted. So (2,0), (1,0) = 2
	# Down: (4,0), (5,0), (6,0) — but (6,0) is corner, restricted. So (4,0), (5,0) = 2
	# Total: 2 + 2 + 2 = 6
	assert_eq(moves.size(), 6, "Attacker blocked by king and restricted from corners")


func test_non_king_cannot_enter_throne() -> void:
	begin("Non-king cannot enter throne")
	var b := empty_board()
	place(b, Vector2i(3, 0), BoardRulesScript.PieceType.ATTACKER)
	# Throne at (3,3) is empty — attacker should be blocked
	b.active_side = BoardRulesScript.Side.ATTACKER

	var moves := b.get_legal_moves_for_piece(Vector2i(3, 0))
	assert_true(Vector2i(3, 3) not in moves, "Attacker cannot enter throne")
	assert_true(Vector2i(3, 2) in moves, "Attacker can reach (3,2) before throne")


func test_non_king_cannot_enter_corner() -> void:
	begin("Non-king cannot enter corner")
	var b := empty_board()
	place(b, Vector2i(0, 3), BoardRulesScript.PieceType.DEFENDER)
	place(b, Vector2i(3, 3), BoardRulesScript.PieceType.KING)
	b.active_side = BoardRulesScript.Side.DEFENDER

	var moves := b.get_legal_moves_for_piece(Vector2i(0, 3))
	assert_true(Vector2i(0, 0) not in moves, "Defender cannot enter corner (0,0)")
	assert_true(Vector2i(0, 6) not in moves, "Defender cannot enter corner (0,6)")


func test_king_can_enter_throne() -> void:
	begin("King can enter throne")
	var b := empty_board()
	place(b, Vector2i(3, 0), BoardRulesScript.PieceType.KING)
	b.active_side = BoardRulesScript.Side.DEFENDER

	var moves := b.get_legal_moves_for_piece(Vector2i(3, 0))
	assert_true(Vector2i(3, 3) in moves, "King can enter throne")


func test_king_can_enter_corner() -> void:
	begin("King can enter corner")
	var b := empty_board()
	place(b, Vector2i(0, 3), BoardRulesScript.PieceType.KING)
	b.active_side = BoardRulesScript.Side.DEFENDER

	var moves := b.get_legal_moves_for_piece(Vector2i(0, 3))
	assert_true(Vector2i(0, 0) in moves, "King can enter corner (0,0)")
	assert_true(Vector2i(0, 6) in moves, "King can enter corner (0,6)")


# --- Capture Tests ---

func test_basic_custodial_capture() -> void:
	begin("Basic custodial capture")
	var b := empty_board()
	place(b, Vector2i(3, 3), BoardRulesScript.PieceType.KING)
	# Defender at (2,4), Attacker at (2,5), moving attacker from (2,3) to create sandwich
	# Actually let's do a simpler setup:
	# Attacker at (2,0), Defender at (2,2), Attacker moves from (2,0) to (2,1) to sandwich
	# No wait — need attacker on the other side too.
	# Setup: Defender at (2,3), Attacker at (2,4), another Attacker at (2,1) moves to (2,2)
	place(b, Vector2i(2, 3), BoardRulesScript.PieceType.DEFENDER)
	place(b, Vector2i(2, 4), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(2, 1), BoardRulesScript.PieceType.ATTACKER)
	b.active_side = BoardRulesScript.Side.ATTACKER

	var result := b.submit_move(Vector2i(2, 1), Vector2i(2, 2))
	assert_true(result.valid, "Move is valid")
	assert_true(Vector2i(2, 3) in result.captures, "Defender at (2,3) captured")
	assert_eq(b.get_piece(Vector2i(2, 3)), BoardRulesScript.PieceType.NONE, "Captured piece removed")


func test_voluntary_sandwich_no_capture() -> void:
	begin("Voluntary sandwich — no capture")
	var b := empty_board()
	place(b, Vector2i(3, 3), BoardRulesScript.PieceType.KING)
	# Attacker at (4,2) and (4,4), Defender moves into (4,3) from below — should NOT be captured
	place(b, Vector2i(4, 2), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(4, 4), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(5, 3), BoardRulesScript.PieceType.DEFENDER)
	b.active_side = BoardRulesScript.Side.DEFENDER

	var result := b.submit_move(Vector2i(5, 3), Vector2i(4, 3))
	assert_true(result.valid, "Move is valid")
	assert_eq(result.captures.size(), 0, "No captures — voluntary sandwich")
	assert_eq(b.get_piece(Vector2i(4, 3)), BoardRulesScript.PieceType.DEFENDER, "Defender survives")


func test_multi_capture() -> void:
	begin("Multi-capture on different axes")
	var b := empty_board()
	place(b, Vector2i(0, 0), BoardRulesScript.PieceType.KING)
	# Attacker moves from (3,6) to (3,5) — captures defenders on two axes
	# Defender at (2,5) flanked by attacker at (1,5) above and (3,5) moving in
	# Defender at (4,5) flanked by attacker at (5,5) below and (3,5) moving in
	place(b, Vector2i(2, 5), BoardRulesScript.PieceType.DEFENDER)
	place(b, Vector2i(1, 5), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(4, 5), BoardRulesScript.PieceType.DEFENDER)
	place(b, Vector2i(5, 5), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(3, 6), BoardRulesScript.PieceType.ATTACKER)
	b.active_side = BoardRulesScript.Side.ATTACKER

	var result := b.submit_move(Vector2i(3, 6), Vector2i(3, 5))
	assert_true(result.valid, "Move is valid")
	assert_eq(result.captures.size(), 2, "Two captures from one move")
	assert_true(Vector2i(2, 5) in result.captures, "Defender at (2,5) captured")
	assert_true(Vector2i(4, 5) in result.captures, "Defender at (4,5) captured")


func test_corner_as_hostile_for_capture() -> void:
	begin("Corner acts as hostile for capture")
	var b := empty_board()
	place(b, Vector2i(3, 3), BoardRulesScript.PieceType.KING)
	# Defender at (0,1), Attacker moves to (0,2) — corner (0,0) flanks
	# Wait, corner is at (0,0). Defender at (0,1) is between corner and attacker at (0,2)
	place(b, Vector2i(0, 1), BoardRulesScript.PieceType.DEFENDER)
	place(b, Vector2i(0, 4), BoardRulesScript.PieceType.ATTACKER)
	b.active_side = BoardRulesScript.Side.ATTACKER

	var result := b.submit_move(Vector2i(0, 4), Vector2i(0, 2))
	assert_true(result.valid, "Move is valid")
	assert_true(Vector2i(0, 1) in result.captures, "Defender captured between attacker and corner")


func test_empty_throne_as_hostile_for_capture() -> void:
	begin("Empty throne acts as hostile for capture")
	var b := empty_board()
	# King is NOT on throne — throne is empty and hostile
	place(b, Vector2i(0, 3), BoardRulesScript.PieceType.KING)
	# Defender at (3,4), Attacker moves to (3,5) — throne at (3,3) flanks
	# Wait, that's not right. Throne is at (3,3). Defender at (3,4) is between
	# throne (3,3) and attacker at (3,5).
	place(b, Vector2i(3, 4), BoardRulesScript.PieceType.DEFENDER)
	place(b, Vector2i(3, 6), BoardRulesScript.PieceType.ATTACKER)
	b.active_side = BoardRulesScript.Side.ATTACKER

	var result := b.submit_move(Vector2i(3, 6), Vector2i(3, 5))
	assert_true(result.valid, "Move is valid")
	assert_true(Vector2i(3, 4) in result.captures, "Defender captured between attacker and empty throne")


func test_king_not_captured_by_sandwich() -> void:
	begin("King not captured by 2-sided sandwich")
	var b := empty_board()
	# King at (5,4), attacker at (5,5), attacker moves from (5,0) to (5,3) to sandwich
	place(b, Vector2i(5, 4), BoardRulesScript.PieceType.KING)
	place(b, Vector2i(5, 5), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(5, 0), BoardRulesScript.PieceType.ATTACKER)
	b.active_side = BoardRulesScript.Side.ATTACKER

	var result := b.submit_move(Vector2i(5, 0), Vector2i(5, 3))
	assert_true(result.valid, "Move is valid")
	assert_eq(result.captures.size(), 0, "King not captured by sandwich")
	assert_eq(b.get_piece(Vector2i(5, 4)), BoardRulesScript.PieceType.KING, "King survives")


# --- King Capture Tests ---

func test_king_captured_four_sides() -> void:
	begin("King captured — four attackers")
	var b := empty_board()
	# King at (5,4), attackers on 3 sides, fourth moves in from below
	place(b, Vector2i(5, 4), BoardRulesScript.PieceType.KING)
	place(b, Vector2i(4, 4), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(5, 5), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(5, 3), BoardRulesScript.PieceType.ATTACKER)
	# Fourth attacker moves in from below
	place(b, Vector2i(6, 4), BoardRulesScript.PieceType.ATTACKER)
	b.active_side = BoardRulesScript.Side.ATTACKER

	# Move an unrelated attacker to trigger the turn — but actually, we need
	# the 4th to MOVE into position. Let me rearrange: 3 already adjacent,
	# 4th moves in.
	# King at (5,4). Adjacent: (4,4)=A, (5,5)=A, (5,3)=A, (6,4)=A. Already 4 sides!
	# So just check directly:
	assert_true(b._is_king_captured(), "King captured — four attackers surround king")


func test_king_not_captured_three_sides() -> void:
	begin("King NOT captured — only 3 attackers")
	var b := empty_board()
	# King at (5,4), only 3 adjacent attackers — should NOT be captured
	place(b, Vector2i(5, 4), BoardRulesScript.PieceType.KING)
	place(b, Vector2i(4, 4), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(5, 5), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(5, 3), BoardRulesScript.PieceType.ATTACKER)
	# (6,4) is empty — only 3 hostile neighbors

	assert_true(not b._is_king_captured(), "King survives with 3 attackers")


func test_king_on_throne_not_captured_three_sides() -> void:
	begin("King on throne — NOT captured at 3 sides")
	var b := empty_board()
	place(b, Vector2i(3, 3), BoardRulesScript.PieceType.KING)  # On throne
	place(b, Vector2i(2, 3), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(4, 3), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(3, 4), BoardRulesScript.PieceType.ATTACKER)
	# Only 3 sides — throne is occupied by king so not hostile
	place(b, Vector2i(3, 0), BoardRulesScript.PieceType.ATTACKER)
	b.active_side = BoardRulesScript.Side.ATTACKER

	# Move an unrelated attacker to not disrupt the setup
	# Actually, let's just directly test _is_king_captured
	assert_true(not b._is_king_captured(), "King on throne not captured at 3 sides (throne not hostile while occupied)")


func test_king_three_attackers_plus_hostile_tile() -> void:
	begin("King captured — 3 attackers + corner tile")
	var b := empty_board()
	# King at (0,1), corner at (0,0), attackers at (0,2), (1,1), and need one more
	# Wait — king near corner. King at (1,0), corner at (0,0)
	# Attackers at (1,1), (2,0), move attacker to (0,0)... no, corner is a tile not a piece.
	# King at (0,1): adjacent = (0,0)=corner, (0,2), (1,1). Need attacker at (0,2), (1,1), and...
	# that's corner + 2 attackers = 3 hostile. Need 4.
	# King has 4 adjacent: up=out of bounds, down=(1,1), left=(0,0)=corner, right=(0,2)
	# So only 3 adjacent cells (top is out of bounds). King can't be captured with only 3 neighbors.
	#
	# Better: King at (1,6), corner at (0,6). Adjacent: (0,6)=corner, (2,6), (1,5). Up=(0,6) corner.
	# Same problem — edge reduces neighbors.
	#
	# King at (1,1): adjacent = (0,1), (2,1), (1,0), (1,2) — all 4 in bounds.
	# No hostile tiles nearby. Let's use empty throne.
	# King at (2,3): adjacent = (1,3), (3,3)=throne(empty), (2,2), (2,4)
	place(b, Vector2i(2, 3), BoardRulesScript.PieceType.KING)
	place(b, Vector2i(1, 3), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(2, 2), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(2, 4), BoardRulesScript.PieceType.ATTACKER)
	# (3,3) is empty throne — hostile
	# So: 3 attackers + empty throne = 4 hostile = captured
	assert_true(b._is_king_captured(), "King captured: 3 attackers + empty throne")


func test_king_three_attackers_one_defender_no_capture() -> void:
	begin("King NOT captured — 3 attackers + 1 defender")
	var b := empty_board()
	place(b, Vector2i(3, 4), BoardRulesScript.PieceType.KING)
	place(b, Vector2i(2, 4), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(4, 4), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(3, 5), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(3, 3), BoardRulesScript.PieceType.DEFENDER)  # Friendly — not hostile

	assert_true(not b._is_king_captured(), "King not captured: defender is friendly")


# --- Win Condition Tests ---

func test_king_escapes_to_corner() -> void:
	begin("King escapes to corner — defender wins")
	var b := empty_board()
	place(b, Vector2i(0, 3), BoardRulesScript.PieceType.KING)
	b.active_side = BoardRulesScript.Side.DEFENDER

	var result := b.submit_move(Vector2i(0, 3), Vector2i(0, 0))
	assert_true(result.valid, "Move is valid")
	assert_eq(result.win, BoardRulesScript.WinReason.KING_ESCAPED, "King escaped — defender wins")
	assert_eq(b.winner, BoardRulesScript.Side.DEFENDER, "Winner is defender")
	assert_true(not b.match_active, "Match ended")


func test_king_escape_priority_over_capture() -> void:
	begin("King escape takes priority over other captures")
	var b := empty_board()
	# King at (0,1) moves to corner (0,0). Attacker at (1,0) could theoretically
	# be "captured" between king at (0,0) and defender at (2,0) — but the game
	# ends on escape before captures are processed.
	place(b, Vector2i(0, 1), BoardRulesScript.PieceType.KING)
	place(b, Vector2i(1, 0), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(2, 0), BoardRulesScript.PieceType.DEFENDER)
	b.active_side = BoardRulesScript.Side.DEFENDER

	var result := b.submit_move(Vector2i(0, 1), Vector2i(0, 0))
	assert_eq(result.win, BoardRulesScript.WinReason.KING_ESCAPED, "King escape wins immediately")
	assert_eq(result.captures.size(), 0, "No captures processed — game ended on escape")


func test_no_legal_moves_loses() -> void:
	begin("No legal moves — player loses")
	var b := empty_board()
	# Create a position where defender (king only) has no legal moves
	# King at (0,1), surrounded by attackers at (0,2), (1,1), and edges
	# King at (0,0) would be a corner = instant win. So:
	# King at (1,1), attackers at (0,1), (1,0), (1,2), (2,1)
	# But that's 4-sided capture = king captured, not no-legal-moves.
	# Need king blocked but not captured.
	# King at (1,1), defenders at (0,1), (1,0) — these block king but aren't hostile.
	# Attackers at (1,2), (2,1). King is blocked by friendlies + enemies but not surrounded on all 4 by hostiles.
	# (0,1)=defender, (1,0)=defender, (1,2)=attacker, (2,1)=attacker = 2 hostile, not captured.
	# King has no moves because all 4 adjacent are occupied.
	# Defenders also need no moves. Place defenders so they're also blocked.
	# Defender at (0,1): adjacent = out-of-bounds(up), (0,0)=corner(restricted), (0,2), (1,1)=king
	# If (0,2) is also blocked by an attacker, defender at (0,1) has no moves.
	place(b, Vector2i(1, 1), BoardRulesScript.PieceType.KING)
	place(b, Vector2i(0, 1), BoardRulesScript.PieceType.DEFENDER)
	place(b, Vector2i(1, 0), BoardRulesScript.PieceType.DEFENDER)
	place(b, Vector2i(1, 2), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(2, 1), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(0, 2), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(2, 0), BoardRulesScript.PieceType.ATTACKER)
	# Defender (0,1): up=OOB, down=(1,1)king, left=(0,0)corner-restricted, right=(0,2)attacker → no moves
	# Defender (1,0): up=(0,0)corner-restricted, down=(2,0)attacker, left=OOB, right=(1,1)king → no moves
	# King (1,1): all 4 adjacent occupied → no moves
	# Now attacker makes a move (any move), then it's defender's turn with no legal moves
	place(b, Vector2i(5, 5), BoardRulesScript.PieceType.ATTACKER)
	b.active_side = BoardRulesScript.Side.ATTACKER

	var result := b.submit_move(Vector2i(5, 5), Vector2i(5, 4))
	assert_eq(result.win, BoardRulesScript.WinReason.NO_LEGAL_MOVES, "Defender has no legal moves — loses")
	assert_eq(b.winner, BoardRulesScript.Side.ATTACKER, "Attacker wins by stalemate")


# --- Turn Order Tests ---

func test_attacker_moves_first() -> void:
	begin("Attacker moves first")
	var b := fresh_board()
	assert_eq(b.active_side, BoardRulesScript.Side.ATTACKER, "Attacker goes first")

	# Defender tries to move — should fail
	var result := b.submit_move(Vector2i(2, 2), Vector2i(2, 1))
	assert_true(not result.valid, "Defender cannot move on attacker's turn")


func test_turns_alternate() -> void:
	begin("Turns alternate")
	var b := fresh_board()
	assert_eq(b.active_side, BoardRulesScript.Side.ATTACKER, "Starts as attacker turn")

	var result := b.submit_move(Vector2i(0, 2), Vector2i(0, 1))
	assert_true(result.valid, "Attacker move valid")
	assert_eq(b.active_side, BoardRulesScript.Side.DEFENDER, "Now defender's turn")

	result = b.submit_move(Vector2i(2, 2), Vector2i(2, 1))
	assert_true(result.valid, "Defender move valid")
	assert_eq(b.active_side, BoardRulesScript.Side.ATTACKER, "Back to attacker's turn")


# --- Misc Tests ---

func test_all_defenders_captured_king_survives() -> void:
	begin("All defenders captured but king survives")
	var b := empty_board()
	# Only king remains for defender side — game should continue
	place(b, Vector2i(3, 4), BoardRulesScript.PieceType.KING)
	place(b, Vector2i(0, 0), BoardRulesScript.PieceType.ATTACKER)
	place(b, Vector2i(6, 6), BoardRulesScript.PieceType.ATTACKER)
	b.active_side = BoardRulesScript.Side.ATTACKER

	assert_true(b.match_active, "Match still active with only king")
	assert_eq(b.get_piece_count(BoardRulesScript.Side.DEFENDER), 1, "Only king remains")

	var result := b.submit_move(Vector2i(0, 0), Vector2i(0, 1))
	assert_true(result.valid, "Game continues normally")
	assert_eq(result.win, BoardRulesScript.WinReason.NONE, "No win — king can still escape")


func test_king_threat_count() -> void:
	begin("King threat count")
	var b := empty_board()
	place(b, Vector2i(3, 4), BoardRulesScript.PieceType.KING)
	assert_eq(b.get_king_threat_count(), 0, "No threats")

	place(b, Vector2i(2, 4), BoardRulesScript.PieceType.ATTACKER)
	assert_eq(b.get_king_threat_count(), 1, "One threat")

	place(b, Vector2i(4, 4), BoardRulesScript.PieceType.ATTACKER)
	assert_eq(b.get_king_threat_count(), 2, "Two threats")

	place(b, Vector2i(3, 5), BoardRulesScript.PieceType.ATTACKER)
	assert_eq(b.get_king_threat_count(), 3, "Three threats")


func test_legal_move_generation_completeness() -> void:
	begin("Legal move generation — full board")
	var b := fresh_board()
	var attacker_moves := b.get_all_legal_moves(BoardRulesScript.Side.ATTACKER)
	var defender_moves := b.get_all_legal_moves(BoardRulesScript.Side.DEFENDER)

	# With the starting layout, both sides should have moves
	assert_true(attacker_moves.size() > 0, "Attackers have legal moves at start (%d)" % attacker_moves.size())
	assert_true(defender_moves.size() > 0, "Defenders have legal moves at start (%d)" % defender_moves.size())
	# Attackers have more pieces and more edge positions — should have more moves
	assert_true(attacker_moves.size() > defender_moves.size(), "Attackers have more moves than defenders")
