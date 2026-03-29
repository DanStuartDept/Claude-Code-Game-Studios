## Board Rules Engine — Production Autoload Singleton
##
## Pure logic engine for Fidchell board game rules. Owns the board data model,
## move validation, custodial capture logic, and win condition detection.
## Emits signals consumed by Board UI, AI System, Campaign, Audio, and Tutorial.
##
## Architecture: Foundation Layer (ADR-0001). Zero upstream dependencies.
## See: design/gdd/board-rules-engine.md
extends Node


# --- Enums ---

enum Side { ATTACKER, DEFENDER }
enum PieceType { NONE, ATTACKER, DEFENDER, KING }
enum TileType { NORMAL, THRONE, CORNER }
enum WinReason { NONE, KING_ESCAPED, KING_CAPTURED, NO_LEGAL_MOVES }
enum MatchMode { STANDARD, SCRIPTED }


# --- Signals ---

## Emitted after a piece is moved on the board.
signal piece_moved(piece_type: int, from_pos: Vector2i, to_pos: Vector2i)

## Emitted after a piece is captured and removed. One emission per captured piece.
signal piece_captured(piece_type: int, position: Vector2i, captured_by: Vector2i)

## Emitted after the active side switches.
signal turn_changed(new_active_side: int)

## Emitted when a win condition is met or a scripted match resolves.
signal match_ended(result: Dictionary)

## Emitted when the King has 2+ adjacent attackers (informational, for UI/audio).
signal king_threatened(king_pos: Vector2i, threat_count: int)


# --- Board Configuration (data-driven, overridable by BoardLayout Resource in S1-02) ---

## Width and height of the board grid.
var board_size: int = 7

## Position of the throne tile.
var throne_pos: Vector2i = Vector2i(3, 3)

## Positions of the four corner tiles.
var corner_positions: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, 6), Vector2i(6, 0), Vector2i(6, 6)
]

## The four orthogonal directions.
var directions: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)
]

## Starting positions for attacker pieces.
var attacker_start_positions: Array[Vector2i] = [
	Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4),
	Vector2i(1, 3),
	Vector2i(2, 0), Vector2i(2, 6),
	Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 5), Vector2i(3, 6),
	Vector2i(4, 0), Vector2i(4, 6),
	Vector2i(5, 3),
	Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4),
]

## Starting positions for defender pieces.
var defender_start_positions: Array[Vector2i] = [
	Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4),
	Vector2i(3, 2), Vector2i(3, 4),
	Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4),
]

## Starting position for the king.
var king_start_pos: Vector2i = Vector2i(3, 3)

## Number of adjacent attackers required to emit king_threatened signal.
var king_threatened_threshold: int = 2

## Number of sides required to capture the king.
var king_capture_sides: int = 4


# --- Match State ---

var _grid: Array = []  # 2D array [row][col] of PieceType
var _active_side: int = Side.ATTACKER
var _winner: int = -1
var _win_reason: int = WinReason.NONE
var _match_active: bool = false
var _match_mode: int = MatchMode.STANDARD
var _player_side: int = Side.DEFENDER
var _king_pos: Vector2i = Vector2i(3, 3)
var _move_count: int = 0


# --- Lifecycle ---

func _ready() -> void:
	_init_grid()


func _init_grid() -> void:
	_grid = []
	for row in board_size:
		var row_data: Array = []
		for col in board_size:
			row_data.append(PieceType.NONE)
		_grid.append(row_data)


# --- Public API: Match Control ---

## Start a new match. Clears the board, places pieces, and sets the active side.
## In SCRIPTED mode, the board is set up but no turns are processed —
## call resolve_scripted_match() to emit the predetermined result.
func start_match(mode: int = MatchMode.STANDARD, player_side: int = Side.DEFENDER) -> void:
	_match_mode = mode
	_player_side = player_side
	_active_side = Side.ATTACKER
	_winner = -1
	_win_reason = WinReason.NONE
	_match_active = true
	_move_count = 0

	_init_grid()

	for pos in attacker_start_positions:
		_grid[pos.x][pos.y] = PieceType.ATTACKER

	for pos in defender_start_positions:
		_grid[pos.x][pos.y] = PieceType.DEFENDER

	_grid[king_start_pos.x][king_start_pos.y] = PieceType.KING
	_king_pos = king_start_pos


## Resolve a scripted match immediately. Skips gameplay and emits match_ended.
## Only valid when the match was started in SCRIPTED mode.
func resolve_scripted_match(winner: int, reason: int) -> void:
	if _match_mode != MatchMode.SCRIPTED:
		return
	if not _match_active:
		return

	_winner = winner
	_win_reason = reason
	_match_active = false

	var result := _build_match_result()
	match_ended.emit(result)


## Submit a move from the active side. Returns a result dictionary.
## Result keys: valid (bool), captures (Array[Vector2i]), win (WinReason), error (String).
func submit_move(from: Vector2i, to: Vector2i) -> Dictionary:
	var result := {
		"valid": false,
		"captures": [] as Array[Vector2i],
		"win": WinReason.NONE,
		"error": "",
	}

	if not _match_active:
		result.error = "No active match"
		return result

	if _match_mode == MatchMode.SCRIPTED:
		result.error = "Cannot submit moves in scripted mode"
		return result

	var piece := get_piece(from)
	if piece == PieceType.NONE:
		result.error = "No piece at source"
		return result

	if not _piece_belongs_to(piece, _active_side):
		result.error = "Piece belongs to other side"
		return result

	var legal := get_legal_moves(from)
	if to not in legal:
		result.error = "Illegal move"
		return result

	# --- Execute move ---
	_grid[from.x][from.y] = PieceType.NONE
	_grid[to.x][to.y] = piece

	if piece == PieceType.KING:
		_king_pos = to

	_move_count += 1
	result.valid = true

	piece_moved.emit(piece, from, to)

	# --- Check King escape (before captures) ---
	if piece == PieceType.KING and get_tile_type(to) == TileType.CORNER:
		_win_reason = WinReason.KING_ESCAPED
		_winner = Side.DEFENDER
		_match_active = false
		result.win = WinReason.KING_ESCAPED
		match_ended.emit(_build_match_result())
		return result

	# --- Check captures ---
	result.captures = _detect_captures(to, piece)
	for cap_pos in result.captures:
		var captured_piece := get_piece(cap_pos)
		_grid[cap_pos.x][cap_pos.y] = PieceType.NONE
		piece_captured.emit(captured_piece, cap_pos, to)

	# --- Check King capture (4-sided enclosure) ---
	if _is_king_captured():
		_win_reason = WinReason.KING_CAPTURED
		_winner = Side.ATTACKER
		_match_active = false
		result.win = WinReason.KING_CAPTURED
		match_ended.emit(_build_match_result())
		return result

	# --- Switch turns ---
	_active_side = Side.DEFENDER if _active_side == Side.ATTACKER else Side.ATTACKER
	turn_changed.emit(_active_side)

	# --- Check no legal moves ---
	if get_all_legal_moves(_active_side).is_empty():
		_win_reason = WinReason.NO_LEGAL_MOVES
		_winner = Side.DEFENDER if _active_side == Side.ATTACKER else Side.ATTACKER
		_match_active = false
		result.win = WinReason.NO_LEGAL_MOVES
		match_ended.emit(_build_match_result())
		return result

	# --- Check king threat (informational) ---
	var threat_count := get_king_threat_count()
	if threat_count >= king_threatened_threshold:
		king_threatened.emit(_king_pos, threat_count)

	return result


# --- Public API: Queries ---

## Return the piece type at the given board position.
func get_piece(pos: Vector2i) -> int:
	if not is_in_bounds(pos):
		return PieceType.NONE
	return _grid[pos.x][pos.y]


## Return the tile type at the given board position.
func get_tile_type(pos: Vector2i) -> int:
	if pos == throne_pos:
		return TileType.THRONE
	if pos in corner_positions:
		return TileType.CORNER
	return TileType.NORMAL


## Return whether the given position is within board bounds.
func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < board_size and pos.y >= 0 and pos.y < board_size


## Return all legal destination positions for the piece at the given position.
func get_legal_moves(piece_pos: Vector2i) -> Array[Vector2i]:
	var piece := get_piece(piece_pos)
	if piece == PieceType.NONE:
		return []

	var moves: Array[Vector2i] = []
	for dir in directions:
		var check := piece_pos + dir
		while is_in_bounds(check):
			if get_piece(check) != PieceType.NONE:
				break
			if _is_restricted_tile(check, piece):
				break
			moves.append(check)
			check += dir
	return moves


## Return all legal moves for the given side as an array of {from, to} dictionaries.
func get_all_legal_moves(side: int) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	for row in board_size:
		for col in board_size:
			var pos := Vector2i(row, col)
			var piece := get_piece(pos)
			if piece != PieceType.NONE and _piece_belongs_to(piece, side):
				for dest in get_legal_moves(pos):
					moves.append({"from": pos, "to": dest})
	return moves


## Return a snapshot of the full board state.
func get_board_state() -> Dictionary:
	var grid_copy: Array = []
	for row in board_size:
		var row_data: Array = []
		for col in board_size:
			row_data.append(_grid[row][col])
		grid_copy.append(row_data)

	return {
		"grid": grid_copy,
		"active_side": _active_side,
		"winner": _winner,
		"win_reason": _win_reason,
		"match_active": _match_active,
		"match_mode": _match_mode,
		"player_side": _player_side,
		"king_pos": _king_pos,
		"move_count": _move_count,
	}


## Return the number of adjacent attacker pieces threatening the king.
func get_king_threat_count() -> int:
	var count := 0
	for dir in directions:
		var adj := _king_pos + dir
		if is_in_bounds(adj) and get_piece(adj) == PieceType.ATTACKER:
			count += 1
	return count


## Return the count of pieces belonging to the given side.
func get_piece_count(side: int) -> int:
	var count := 0
	for row in board_size:
		for col in board_size:
			var piece: int = _grid[row][col]
			if piece != PieceType.NONE and _piece_belongs_to(piece, side):
				count += 1
	return count


## Return whether a match is currently in progress.
func is_match_active() -> bool:
	return _match_active


## Return the current active side.
func get_active_side() -> int:
	return _active_side


## Return which side the player controls.
func get_player_side() -> int:
	return _player_side


## Return the current match mode.
func get_match_mode() -> int:
	return _match_mode


## Return the current move count.
func get_move_count() -> int:
	return _move_count


# --- Internal: Capture Logic ---

func _piece_belongs_to(piece: int, side: int) -> bool:
	if side == Side.ATTACKER:
		return piece == PieceType.ATTACKER
	return piece == PieceType.DEFENDER or piece == PieceType.KING


func _is_restricted_tile(pos: Vector2i, piece: int) -> bool:
	if piece == PieceType.KING:
		return false
	var tile := get_tile_type(pos)
	return tile == TileType.THRONE or tile == TileType.CORNER


func _is_hostile(pos: Vector2i, to_side: int) -> bool:
	if not is_in_bounds(pos):
		return false

	var piece := get_piece(pos)

	if piece != PieceType.NONE and not _piece_belongs_to(piece, to_side):
		return true

	if get_tile_type(pos) == TileType.CORNER:
		return true

	if get_tile_type(pos) == TileType.THRONE and piece == PieceType.NONE:
		return true

	return false


func _detect_captures(moved_to: Vector2i, moved_piece: int) -> Array[Vector2i]:
	var captures: Array[Vector2i] = []
	var mover_side: int = Side.ATTACKER if moved_piece == PieceType.ATTACKER else Side.DEFENDER

	for dir in directions:
		var adjacent := moved_to + dir
		if not is_in_bounds(adjacent):
			continue

		var adj_piece := get_piece(adjacent)
		if adj_piece == PieceType.NONE:
			continue

		if _piece_belongs_to(adj_piece, mover_side):
			continue

		# King uses 4-sided capture, not custodial
		if adj_piece == PieceType.KING:
			continue

		var opposite := adjacent + dir
		var enemy_side: int = Side.DEFENDER if mover_side == Side.ATTACKER else Side.ATTACKER
		if _is_hostile(opposite, enemy_side):
			captures.append(adjacent)

	return captures


func _is_king_captured() -> bool:
	var hostile_count := 0
	for dir in directions:
		var adj := _king_pos + dir
		if not is_in_bounds(adj):
			continue

		var adj_piece := get_piece(adj)

		if adj_piece == PieceType.ATTACKER:
			hostile_count += 1
			continue

		if get_tile_type(adj) == TileType.CORNER:
			hostile_count += 1
			continue

		if get_tile_type(adj) == TileType.THRONE and adj_piece == PieceType.NONE:
			hostile_count += 1
			continue

	return hostile_count >= king_capture_sides


func _build_match_result() -> Dictionary:
	return {
		"winner": _winner,
		"reason": _win_reason,
		"move_count": _move_count,
		"pieces_remaining": {
			"attacker": get_piece_count(Side.ATTACKER),
			"defender": get_piece_count(Side.DEFENDER),
		},
	}


# --- Debug Utility ---

## Return a human-readable string representation of the board.
func board_to_string() -> String:
	var result := "    0   1   2   3   4   5   6\n"
	for row in board_size:
		result += str(row) + "  "
		for col in board_size:
			var piece: int = _grid[row][col]
			match piece:
				PieceType.NONE:
					var tile := get_tile_type(Vector2i(row, col))
					if tile == TileType.THRONE:
						result += " +  "
					elif tile == TileType.CORNER:
						result += " *  "
					else:
						result += " .  "
				PieceType.ATTACKER:
					result += " A  "
				PieceType.DEFENDER:
					result += " D  "
				PieceType.KING:
					result += " K  "
		result += "\n"
	return result
