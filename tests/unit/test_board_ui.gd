## GdUnit4 tests for Board UI — Board Rendering (S1-07)
##
## Covers S1-07 acceptance criteria:
## - Board renders correctly (layout math, piece placement)
## - Responsive scaling for different screen sizes
## - Pieces distinguishable (correct types placed)
## - Coordinate conversion round-trips
## - Signal-driven state updates
class_name TestBoardUI
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
	# Set a known size for deterministic tests
	_ui.size = Vector2(400, 520)
	add_child(_ui)


func after_test() -> void:
	_ui.queue_free()
	_board.queue_free()


# --- Helpers ---

func _setup_board_ui(screen_size: Vector2 = Vector2(400, 520)) -> void:
	_board.start_match(_board.MatchMode.STANDARD, _board.Side.DEFENDER)
	_ui.size = screen_size
	var config: BoardUIConfig = BoardUIConfigScript.new()
	_ui.configure(_board, config)


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

func test_configure_sets_up_board() -> void:
	_setup_board_ui()
	assert_bool(_ui._configured).is_true()
	assert_float(_ui.get_cell_size()).is_greater(0.0)


func test_configure_with_null_config_uses_defaults() -> void:
	_board.start_match(_board.MatchMode.STANDARD, _board.Side.DEFENDER)
	_ui.size = Vector2(400, 520)
	_ui.configure(_board, null)
	assert_bool(_ui._configured).is_true()
	assert_float(_ui.get_cell_size()).is_greater(0.0)


# ---------------------------------------------------------------------------
# Layout calculation — responsive scaling
# ---------------------------------------------------------------------------

func test_cell_size_fits_within_available_space() -> void:
	_setup_board_ui(Vector2(400, 520))
	var cell_size: float = _ui.get_cell_size()
	var board_pixel_size: float = cell_size * 7
	# Board should fit within width and height minus margin
	assert_float(board_pixel_size).is_less_equal(400.0)
	assert_float(board_pixel_size).is_less_equal(520.0 - 120.0)  # ui_margin = 120


func test_cell_size_respects_min_tap_target() -> void:
	# Very small screen — cell size should not go below 44pt
	_setup_board_ui(Vector2(200, 200))
	var cell_size: float = _ui.get_cell_size()
	assert_float(cell_size).is_greater_equal(44.0)


func test_cell_size_respects_max_cap() -> void:
	# Very large screen — cell size should not exceed 100pt
	_setup_board_ui(Vector2(2000, 2000))
	var cell_size: float = _ui.get_cell_size()
	assert_float(cell_size).is_less_equal(100.0)


func test_layout_phone_small() -> void:
	# 4.7" phone approximation (320x568 points)
	_setup_board_ui(Vector2(320, 568))
	var cell_size: float = _ui.get_cell_size()
	# Should be at least min_tap_target
	assert_float(cell_size).is_greater_equal(44.0)
	# Board should fit
	assert_float(cell_size * 7).is_less_equal(320.0)


func test_layout_phone_large() -> void:
	# 6.7" phone approximation (428x926 points)
	_setup_board_ui(Vector2(428, 926))
	var cell_size: float = _ui.get_cell_size()
	assert_float(cell_size).is_greater_equal(44.0)
	assert_float(cell_size * 7).is_less_equal(428.0)


func test_layout_tablet() -> void:
	# 10" tablet approximation (768x1024 points)
	_setup_board_ui(Vector2(768, 1024))
	var cell_size: float = _ui.get_cell_size()
	# Should be capped at max
	assert_float(cell_size).is_less_equal(100.0)
	assert_float(cell_size).is_greater_equal(44.0)


func test_board_origin_centers_board() -> void:
	_setup_board_ui(Vector2(500, 620))
	var origin: Vector2 = _ui.get_board_origin()
	var cell_size: float = _ui.get_cell_size()
	var board_size_px: float = cell_size * 7
	# Board should be centered horizontally
	var expected_x: float = (500.0 - board_size_px) * 0.5
	assert_float(origin.x).is_equal_approx(expected_x, 1.0)


# ---------------------------------------------------------------------------
# Coordinate conversion
# ---------------------------------------------------------------------------

func test_cell_to_screen_returns_center() -> void:
	_setup_board_ui()
	var cell_size: float = _ui.get_cell_size()
	var origin: Vector2 = _ui.get_board_origin()

	# Cell (0,0) center should be at origin + (0.5 * cell_size, 0.5 * cell_size)
	var screen_pos: Vector2 = _ui.cell_to_screen(Vector2i(0, 0))
	assert_float(screen_pos.x).is_equal_approx(origin.x + cell_size * 0.5, 0.1)
	assert_float(screen_pos.y).is_equal_approx(origin.y + cell_size * 0.5, 0.1)


func test_cell_to_screen_center_cell() -> void:
	_setup_board_ui()
	var cell_size: float = _ui.get_cell_size()
	var origin: Vector2 = _ui.get_board_origin()

	var screen_pos: Vector2 = _ui.cell_to_screen(Vector2i(3, 3))
	assert_float(screen_pos.x).is_equal_approx(origin.x + cell_size * 3.5, 0.1)
	assert_float(screen_pos.y).is_equal_approx(origin.y + cell_size * 3.5, 0.1)


func test_screen_to_cell_valid() -> void:
	_setup_board_ui()
	var origin: Vector2 = _ui.get_board_origin()
	var cell_size: float = _ui.get_cell_size()

	# Tap in center of cell (2, 3)
	var screen_pos := Vector2(origin.x + 3.5 * cell_size, origin.y + 2.5 * cell_size)
	var cell: Vector2i = _ui.screen_to_cell(screen_pos)
	assert_object(cell).is_equal(Vector2i(2, 3))


func test_screen_to_cell_out_of_bounds() -> void:
	_setup_board_ui()
	# Tap outside board
	var cell: Vector2i = _ui.screen_to_cell(Vector2(-10, -10))
	assert_object(cell).is_equal(Vector2i(-1, -1))


func test_cell_screen_roundtrip() -> void:
	_setup_board_ui()
	# Convert cell to screen, then screen back to cell
	for row: int in 7:
		for col: int in 7:
			var original := Vector2i(row, col)
			var screen_pos: Vector2 = _ui.cell_to_screen(original)
			var recovered: Vector2i = _ui.screen_to_cell(screen_pos)
			assert_object(recovered).is_equal(original)


# ---------------------------------------------------------------------------
# Piece placement from board state
# ---------------------------------------------------------------------------

func test_populate_board_places_all_pieces() -> void:
	_setup_board_ui()
	# Standard starting position: 16 attackers + 8 defenders + 1 king = 25
	var piece_count: int = _ui._pieces.size()
	assert_int(piece_count).is_equal(25)


func test_populate_board_attacker_positions() -> void:
	_setup_board_ui()
	# Check a known attacker starting position
	var piece_type: int = _ui.get_piece_at(Vector2i(0, 3))
	assert_int(piece_type).is_equal(_board.PieceType.ATTACKER)


func test_populate_board_defender_positions() -> void:
	_setup_board_ui()
	# Check a known defender starting position (adjacent to throne)
	var piece_type: int = _ui.get_piece_at(Vector2i(3, 2))
	assert_int(piece_type).is_equal(_board.PieceType.DEFENDER)


func test_populate_board_king_position() -> void:
	_setup_board_ui()
	# King starts at throne (3,3)
	var piece_type: int = _ui.get_piece_at(Vector2i(3, 3))
	assert_int(piece_type).is_equal(_board.PieceType.KING)


func test_populate_board_empty_cell() -> void:
	_setup_board_ui()
	# Cell (0,0) is a corner — should be empty at start
	var piece_type: int = _ui.get_piece_at(Vector2i(0, 0))
	assert_int(piece_type).is_equal(0)  # PieceType.NONE


# ---------------------------------------------------------------------------
# Tile type caching
# ---------------------------------------------------------------------------

func test_tile_types_cached() -> void:
	_setup_board_ui()
	# Throne at (3,3)
	assert_int(_ui._tile_types[Vector2i(3, 3)]).is_equal(_board.TileType.THRONE)


func test_corner_tiles_cached() -> void:
	_setup_board_ui()
	# All four corners
	assert_int(_ui._tile_types[Vector2i(0, 0)]).is_equal(_board.TileType.CORNER)
	assert_int(_ui._tile_types[Vector2i(0, 6)]).is_equal(_board.TileType.CORNER)
	assert_int(_ui._tile_types[Vector2i(6, 0)]).is_equal(_board.TileType.CORNER)
	assert_int(_ui._tile_types[Vector2i(6, 6)]).is_equal(_board.TileType.CORNER)


# ---------------------------------------------------------------------------
# Signal-driven state updates
# ---------------------------------------------------------------------------

func test_piece_moved_updates_state() -> void:
	_setup_board_ui()
	# Simulate a move via signal
	_board.piece_moved.emit(_board.PieceType.ATTACKER, Vector2i(0, 3), Vector2i(0, 2))

	assert_int(_ui.get_piece_at(Vector2i(0, 2))).is_equal(_board.PieceType.ATTACKER)
	assert_int(_ui.get_piece_at(Vector2i(0, 3))).is_equal(0)


func test_piece_moved_updates_last_move() -> void:
	_setup_board_ui()
	_board.piece_moved.emit(_board.PieceType.ATTACKER, Vector2i(0, 3), Vector2i(0, 2))

	assert_object(_ui._last_move.from).is_equal(Vector2i(0, 3))
	assert_object(_ui._last_move.to).is_equal(Vector2i(0, 2))


func test_piece_captured_removes_piece() -> void:
	_setup_board_ui()
	# Place a defender at (2, 2) then capture it
	_ui._pieces[Vector2i(2, 2)] = _board.PieceType.DEFENDER
	_board.piece_captured.emit(_board.PieceType.DEFENDER, Vector2i(2, 2), Vector2i(2, 1))

	assert_int(_ui.get_piece_at(Vector2i(2, 2))).is_equal(0)


func test_king_threatened_updates_state() -> void:
	_setup_board_ui()
	_board.king_threatened.emit(Vector2i(3, 3), 2)

	assert_int(_ui._king_threat_count).is_equal(2)
	assert_object(_ui._king_pos).is_equal(Vector2i(3, 3))


func test_turn_changed_updates_active_side() -> void:
	_setup_board_ui()
	_board.turn_changed.emit(_board.Side.DEFENDER)

	assert_int(_ui._active_side).is_equal(_board.Side.DEFENDER)


func test_match_ended_updates_state() -> void:
	_setup_board_ui()
	_board.match_ended.emit({ "winner": _board.Side.DEFENDER, "reason": _board.WinReason.KING_ESCAPED })

	assert_bool(_ui._match_active).is_false()


# ---------------------------------------------------------------------------
# Config loads from .tres
# ---------------------------------------------------------------------------

func test_config_loads_from_tres() -> void:
	var config: Resource = load("res://assets/data/ui/default_board_ui.tres")
	assert_object(config).is_not_null()
	assert_bool(config is BoardUIConfig).is_true()


func test_config_has_correct_defaults() -> void:
	var config: BoardUIConfig = load("res://assets/data/ui/default_board_ui.tres") as BoardUIConfig
	assert_float(config.min_tap_target).is_equal(44.0)
	assert_float(config.max_cell_size).is_equal(100.0)
	assert_float(config.ui_margin).is_equal(120.0)
	assert_float(config.piece_radius_fraction).is_equal(0.35)
	assert_float(config.king_radius_fraction).is_equal(0.40)
