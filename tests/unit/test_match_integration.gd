## GdUnit4 tests for Match Integration (S1-09)
##
## Covers S1-09 acceptance criteria:
## - Player can play a full match against AI opponent
## - Win/loss detected and displayed
## - All systems wired correctly (BoardRules + AI + BoardUI)
## - AI takes turns automatically
## - Match result shows correct information
class_name TestMatchIntegration
extends GdUnitTestSuite


const BoardRulesScript := preload("res://src/core/board_rules.gd")
const AISystemScript := preload("res://src/core/ai_system.gd")
const BoardUIScript := preload("res://src/ui/board_ui.gd")
const BoardUIConfigScript := preload("res://src/data/board_ui_config.gd")
const MatchControllerScript := preload("res://src/ui/match_controller.gd")

var _board: Node
var _ai: Node


func before_test() -> void:
	_board = BoardRulesScript.new()
	_board.name = "BoardRules"
	add_child(_board)
	_ai = AISystemScript.new()
	_ai.name = "AISystem"
	add_child(_ai)


func after_test() -> void:
	_ai.queue_free()
	_board.queue_free()


# --- Helpers ---

func _setup_match(player_side: int = 1, ai_diff: int = 1) -> void:
	_board.start_match(_board.MatchMode.STANDARD, player_side)
	var ai_side: int = 1 - player_side
	_ai.configure(_board, ai_side, ai_diff)
	_ai._mistake_chance = 0.0
	_ai.erratic_disruption_chance = 0.0


func _clear_board() -> void:
	for row: int in _board.board_size:
		for col: int in _board.board_size:
			_board._grid[row][col] = _board.PieceType.NONE
	_board._king_pos = Vector2i(-1, -1)


func _place_piece(pos: Vector2i, piece_type: int) -> void:
	_board._grid[pos.x][pos.y] = piece_type
	if piece_type == _board.PieceType.KING:
		_board._king_pos = pos


func _set_active_side(side: int) -> void:
	_board._active_side = side


# ---------------------------------------------------------------------------
# BoardRules + AI wire correctly
# ---------------------------------------------------------------------------

func test_ai_returns_valid_move_in_match() -> void:
	_setup_match(_board.Side.DEFENDER, 1)
	_set_active_side(_board.Side.ATTACKER)

	var move: Dictionary = _ai.select_move()
	assert_bool(move.is_empty()).is_false()

	var result: Dictionary = _board.submit_move(move.from, move.to)
	assert_bool(result.valid).is_true()


func test_ai_move_triggers_turn_change() -> void:
	_setup_match(_board.Side.DEFENDER, 1)
	_set_active_side(_board.Side.ATTACKER)

	var move: Dictionary = _ai.select_move()
	_board.submit_move(move.from, move.to)

	# After attacker moves, should be defender's turn
	assert_int(_board.get_active_side()).is_equal(_board.Side.DEFENDER)


# ---------------------------------------------------------------------------
# BoardUI receives signals from BoardRules
# ---------------------------------------------------------------------------

func test_board_ui_updates_on_move() -> void:
	_setup_match(_board.Side.DEFENDER, 1)
	_set_active_side(_board.Side.ATTACKER)

	var ui: Control = BoardUIScript.new()
	ui.size = Vector2(400, 520)
	add_child(ui)
	var config: BoardUIConfig = BoardUIConfigScript.new()
	ui.configure(_board, config)

	# Count pieces before
	var pieces_before: int = ui._pieces.size()

	# AI makes a move
	var move: Dictionary = _ai.select_move()
	_board.submit_move(move.from, move.to)

	# Piece should have moved in UI state
	assert_bool(ui._last_move.is_empty()).is_false()

	ui.queue_free()


# ---------------------------------------------------------------------------
# Full match can be played to completion — King escape
# ---------------------------------------------------------------------------

func test_king_escape_ends_match() -> void:
	_setup_match(_board.Side.DEFENDER, 1)
	_clear_board()

	# King one step from corner
	_place_piece(Vector2i(0, 1), _board.PieceType.KING)
	_place_piece(Vector2i(5, 5), _board.PieceType.ATTACKER)
	_set_active_side(_board.Side.DEFENDER)

	var result: Dictionary = _board.submit_move(Vector2i(0, 1), Vector2i(0, 0))
	assert_bool(result.valid).is_true()
	assert_int(result.win).is_equal(_board.WinReason.KING_ESCAPED)
	assert_bool(_board.is_match_active()).is_false()


func test_king_capture_ends_match() -> void:
	_setup_match(_board.Side.ATTACKER, 1)
	_clear_board()

	# King surrounded on 3 sides, attacker can complete the 4th
	_place_piece(Vector2i(3, 3), _board.PieceType.KING)
	_place_piece(Vector2i(2, 3), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(4, 3), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(3, 2), _board.PieceType.ATTACKER)
	_place_piece(Vector2i(3, 6), _board.PieceType.ATTACKER)
	_set_active_side(_board.Side.ATTACKER)

	var result: Dictionary = _board.submit_move(Vector2i(3, 6), Vector2i(3, 4))
	assert_bool(result.valid).is_true()
	assert_int(result.win).is_equal(_board.WinReason.KING_CAPTURED)
	assert_bool(_board.is_match_active()).is_false()


# ---------------------------------------------------------------------------
# Multiple turns can be played
# ---------------------------------------------------------------------------

func test_multiple_turns_alternate_sides() -> void:
	_setup_match(_board.Side.DEFENDER, 1)

	# Attacker turn — use AI
	_set_active_side(_board.Side.ATTACKER)
	var move1: Dictionary = _ai.select_move()
	assert_bool(move1.is_empty()).is_false()
	_board.submit_move(move1.from, move1.to)
	assert_int(_board.get_active_side()).is_equal(_board.Side.DEFENDER)

	# Defender turn — manual move (pick a defender with moves)
	var defender_moves: Array = _board.get_all_legal_moves(_board.Side.DEFENDER)
	assert_bool(defender_moves.size() > 0).is_true()
	if defender_moves.size() > 0:
		var dm: Dictionary = defender_moves[0]
		_board.submit_move(dm.from, dm.to)
		assert_int(_board.get_active_side()).is_equal(_board.Side.ATTACKER)


# ---------------------------------------------------------------------------
# AI plays full game without errors
# ---------------------------------------------------------------------------

func test_ai_vs_ai_completes_match() -> void:
	_board.start_match(_board.MatchMode.STANDARD, _board.Side.DEFENDER)

	# Configure two AIs
	var ai_attacker: Node = AISystemScript.new()
	add_child(ai_attacker)
	ai_attacker.configure(_board, _board.Side.ATTACKER, 1)
	ai_attacker._mistake_chance = 0.0
	ai_attacker.erratic_disruption_chance = 0.0

	var ai_defender: Node = AISystemScript.new()
	add_child(ai_defender)
	ai_defender.configure(_board, _board.Side.DEFENDER, 1)
	ai_defender._mistake_chance = 0.0
	ai_defender.erratic_disruption_chance = 0.0

	# Play up to 200 moves (100 per side)
	var move_count: int = 0
	var max_moves: int = 200

	while _board.is_match_active() and move_count < max_moves:
		var active: int = _board.get_active_side()
		var ai: Node = ai_attacker if active == _board.Side.ATTACKER else ai_defender
		var move: Dictionary = ai.select_move()

		if move.is_empty():
			break

		var result: Dictionary = _board.submit_move(move.from, move.to)
		assert_bool(result.valid).is_true()
		move_count += 1

	# Match should have ended (or hit move limit)
	assert_bool(move_count > 0).is_true()

	ai_attacker.queue_free()
	ai_defender.queue_free()


# ---------------------------------------------------------------------------
# Opponent profile configures AI correctly
# ---------------------------------------------------------------------------

func test_opponent_profile_applies_to_ai() -> void:
	var profile: Resource = load("res://assets/data/opponents/seanan.tres")
	assert_object(profile).is_not_null()

	_board.start_match(_board.MatchMode.STANDARD, _board.Side.DEFENDER)
	_ai.configure(_board, _board.Side.ATTACKER)
	profile.apply_to(_ai)

	assert_int(_ai.difficulty).is_equal(1)
	assert_float(_ai.erratic_disruption_chance).is_equal(0.3)

	var move: Dictionary = _ai.select_move()
	assert_bool(move.is_empty()).is_false()


# ---------------------------------------------------------------------------
# Match result contains expected data
# ---------------------------------------------------------------------------

func test_match_ended_signal_has_result_data() -> void:
	_setup_match(_board.Side.DEFENDER, 1)
	_clear_board()

	# Set up king escape
	_place_piece(Vector2i(0, 1), _board.PieceType.KING)
	_place_piece(Vector2i(5, 5), _board.PieceType.ATTACKER)
	_set_active_side(_board.Side.DEFENDER)

	var received_result: Array = []
	var callback := func(result: Dictionary) -> void:
		received_result.append(result)
	_board.match_ended.connect(callback)

	_board.submit_move(Vector2i(0, 1), Vector2i(0, 0))

	assert_int(received_result.size()).is_equal(1)
	if received_result.size() > 0:
		var result: Dictionary = received_result[0]
		assert_bool(result.has("winner")).is_true()
		assert_bool(result.has("reason")).is_true()
		assert_bool(result.has("move_count")).is_true()
		assert_int(result["winner"]).is_equal(_board.Side.DEFENDER)
		assert_int(result["reason"]).is_equal(_board.WinReason.KING_ESCAPED)


# ---------------------------------------------------------------------------
# Scene files exist
# ---------------------------------------------------------------------------

func test_match_scene_exists() -> void:
	assert_bool(ResourceLoader.exists("res://scenes/match/Match.tscn")).is_true()


func test_menu_scene_exists() -> void:
	assert_bool(ResourceLoader.exists("res://scenes/menu/MainMenu.tscn")).is_true()
