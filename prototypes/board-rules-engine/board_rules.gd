# PROTOTYPE - NOT FOR PRODUCTION
# Question: Do Fidchell board rules produce correct gameplay?
# Date: 2026-03-28

extends RefCounted

# --- Enums ---

enum Side { ATTACKER, DEFENDER }
enum PieceType { NONE, ATTACKER, DEFENDER, KING }
enum TileType { NORMAL, THRONE, CORNER }
enum WinReason { NONE, KING_ESCAPED, KING_CAPTURED, NO_LEGAL_MOVES }

# --- Constants ---

const BOARD_SIZE := 7
const THRONE_POS := Vector2i(3, 3)
const CORNER_POSITIONS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, 6), Vector2i(6, 0), Vector2i(6, 6)
]
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)
]

const ATTACKER_START: Array[Vector2i] = [
	Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4),
	Vector2i(1, 3),
	Vector2i(2, 0), Vector2i(2, 6),
	Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 5), Vector2i(3, 6),
	Vector2i(4, 0), Vector2i(4, 6),
	Vector2i(5, 3),
	Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4),
]

const DEFENDER_START: Array[Vector2i] = [
	Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4),
	Vector2i(3, 2), Vector2i(3, 4),
	Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4),
]

const KING_START := Vector2i(3, 3)

# --- State ---

var grid: Array  # 2D array [row][col] of PieceType
var active_side = Side.ATTACKER
var winner = -1
var win_reason = WinReason.NONE
var match_active: bool = false
var king_pos: Vector2i = KING_START
var move_count: int = 0


func _init() -> void:
	grid = []
	for row in BOARD_SIZE:
		var row_data: Array = []
		for col in BOARD_SIZE:
			row_data.append(PieceType.NONE)
		grid.append(row_data)


# --- Setup ---

func start_match() -> void:
	# Clear board
	for row in BOARD_SIZE:
		for col in BOARD_SIZE:
			grid[row][col] = PieceType.NONE

	# Place pieces
	for pos in ATTACKER_START:
		grid[pos.x][pos.y] = PieceType.ATTACKER

	for pos in DEFENDER_START:
		grid[pos.x][pos.y] = PieceType.DEFENDER

	grid[KING_START.x][KING_START.y] = PieceType.KING
	king_pos = KING_START

	active_side = Side.ATTACKER
	winner = -1
	win_reason = WinReason.NONE
	match_active = true
	move_count = 0


# --- Queries ---

func get_tile_type(pos: Vector2i) -> int:
	if pos == THRONE_POS:
		return TileType.THRONE
	if pos in CORNER_POSITIONS:
		return TileType.CORNER
	return TileType.NORMAL


func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < BOARD_SIZE and pos.y >= 0 and pos.y < BOARD_SIZE


func get_piece(pos: Vector2i) -> int:
	if not is_in_bounds(pos):
		return PieceType.NONE
	return grid[pos.x][pos.y]


func piece_belongs_to(piece: int, side: int) -> bool:
	if side == Side.ATTACKER:
		return piece == PieceType.ATTACKER
	return piece == PieceType.DEFENDER or piece == PieceType.KING


func is_restricted_tile(pos: Vector2i, piece: int) -> bool:
	# Only the King may enter Throne and Corner tiles
	if piece == PieceType.KING:
		return false
	var tile := get_tile_type(pos)
	return tile == TileType.THRONE or tile == TileType.CORNER


func get_legal_moves_for_piece(pos: Vector2i) -> Array[Vector2i]:
	var piece := get_piece(pos)
	if piece == PieceType.NONE:
		return []

	var moves: Array[Vector2i] = []
	for dir in DIRECTIONS:
		var check := pos + dir
		while is_in_bounds(check):
			if get_piece(check) != PieceType.NONE:
				break  # Blocked by another piece
			if is_restricted_tile(check, piece):
				break  # Non-king can't enter throne/corner
			moves.append(check)
			check += dir
	return moves


func get_all_legal_moves(side: int) -> Array[Dictionary]:
	# Returns array of {from: Vector2i, to: Vector2i}
	var moves: Array[Dictionary] = []
	for row in BOARD_SIZE:
		for col in BOARD_SIZE:
			var pos := Vector2i(row, col)
			var piece := get_piece(pos)
			if piece != PieceType.NONE and piece_belongs_to(piece, side):
				for dest in get_legal_moves_for_piece(pos):
					moves.append({"from": pos, "to": dest})
	return moves


# --- Move Execution ---

func submit_move(from: Vector2i, to: Vector2i) -> Dictionary:
	# Returns {valid: bool, captures: Array[Vector2i], win: WinReason, error: String}
	var result := {
		"valid": false,
		"captures": [] as Array[Vector2i],
		"win": WinReason.NONE,
		"error": "",
	}

	if not match_active:
		result.error = "No active match"
		return result

	var piece := get_piece(from)
	if piece == PieceType.NONE:
		result.error = "No piece at source"
		return result

	if not piece_belongs_to(piece, active_side):
		result.error = "Piece belongs to other side"
		return result

	var legal := get_legal_moves_for_piece(from)
	if to not in legal:
		result.error = "Illegal move"
		return result

	# --- Execute move ---
	grid[from.x][from.y] = PieceType.NONE
	grid[to.x][to.y] = piece

	if piece == PieceType.KING:
		king_pos = to

	move_count += 1
	result.valid = true

	# --- Check King escape (before captures) ---
	if piece == PieceType.KING and get_tile_type(to) == TileType.CORNER:
		win_reason = WinReason.KING_ESCAPED
		winner = Side.DEFENDER
		match_active = false
		result.win = WinReason.KING_ESCAPED
		return result

	# --- Check captures ---
	result.captures = _detect_captures(to, piece)
	for cap_pos in result.captures:
		grid[cap_pos.x][cap_pos.y] = PieceType.NONE

	# --- Check King capture (4-sided enclosure) ---
	if _is_king_captured():
		win_reason = WinReason.KING_CAPTURED
		winner = Side.ATTACKER
		match_active = false
		result.win = WinReason.KING_CAPTURED
		return result

	# --- Switch turns ---
	active_side = Side.DEFENDER if active_side == Side.ATTACKER else Side.ATTACKER

	# --- Check no legal moves ---
	if get_all_legal_moves(active_side).is_empty():
		win_reason = WinReason.NO_LEGAL_MOVES
		# The side with no moves loses — their opponent wins
		winner = Side.DEFENDER if active_side == Side.ATTACKER else Side.ATTACKER
		match_active = false
		result.win = WinReason.NO_LEGAL_MOVES

	return result


# --- Capture Logic ---

func _is_hostile(pos: Vector2i, to_side: int) -> bool:
	# Is this position hostile to `to_side`?
	# A position is hostile if it contains an enemy piece or is a hostile tile.
	if not is_in_bounds(pos):
		return false

	var piece := get_piece(pos)

	# Enemy piece is hostile
	if piece != PieceType.NONE and not piece_belongs_to(piece, to_side):
		return true

	# Corner tiles are always hostile
	if get_tile_type(pos) == TileType.CORNER:
		return true

	# Empty throne is hostile
	if get_tile_type(pos) == TileType.THRONE and piece == PieceType.NONE:
		return true

	return false


func _detect_captures(moved_to: Vector2i, moved_piece: PieceType) -> Array[Vector2i]:
	var captures: Array[Vector2i] = []
	var mover_side := Side.ATTACKER if moved_piece == PieceType.ATTACKER else Side.DEFENDER

	for dir in DIRECTIONS:
		var adjacent := moved_to + dir
		if not is_in_bounds(adjacent):
			continue

		var adj_piece := get_piece(adjacent)
		if adj_piece == PieceType.NONE:
			continue

		# Skip friendly pieces
		if piece_belongs_to(adj_piece, mover_side):
			continue

		# Skip king — king uses 4-sided capture, not custodial
		if adj_piece == PieceType.KING:
			continue

		# Check the opposite side for a friendly piece or hostile tile
		var opposite := adjacent + dir
		if _is_hostile(opposite, Side.DEFENDER if mover_side == Side.ATTACKER else Side.ATTACKER):
			captures.append(adjacent)

	return captures


func _is_king_captured() -> bool:
	var hostile_count := 0
	for dir in DIRECTIONS:
		var adj := king_pos + dir
		if not is_in_bounds(adj):
			# Board edge is NOT hostile for king capture
			continue

		var adj_piece := get_piece(adj)

		# Attacker piece is hostile to king
		if adj_piece == PieceType.ATTACKER:
			hostile_count += 1
			continue

		# Corner tile is hostile to king
		if get_tile_type(adj) == TileType.CORNER:
			hostile_count += 1
			continue

		# Empty throne is hostile to king
		if get_tile_type(adj) == TileType.THRONE and adj_piece == PieceType.NONE:
			hostile_count += 1
			continue

	return hostile_count == 4


func get_king_threat_count() -> int:
	var count := 0
	for dir in DIRECTIONS:
		var adj := king_pos + dir
		if is_in_bounds(adj) and get_piece(adj) == PieceType.ATTACKER:
			count += 1
	return count


# --- Utility ---

func get_piece_count(side: int) -> int:
	var count := 0
	for row in BOARD_SIZE:
		for col in BOARD_SIZE:
			var piece = grid[row][col]
			if piece != PieceType.NONE and piece_belongs_to(piece, side):
				count += 1
	return count


func board_to_string() -> String:
	var result := "    0   1   2   3   4   5   6\n"
	for row in BOARD_SIZE:
		result += str(row) + "  "
		for col in BOARD_SIZE:
			var piece = grid[row][col]
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
