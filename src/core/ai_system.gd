## AI System — Autoload Singleton
##
## Two-layer AI for Fidchell: core evaluator (minimax + alpha-beta pruning)
## and personality layer. Consumes board state from BoardRules, returns chosen moves.
## Core evaluator scores positions, personality layer reweights, difficulty injects mistakes.
##
## Architecture: Core Layer (ADR-0001). Depends on Board Rules Engine.
## See: design/gdd/ai-system.md
extends Node


# --- Configuration ---

## Evaluation weights (personality layer in S1-05 will override these).
var w_material: float = 1.0
var w_king_freedom: float = 1.0
var w_king_proximity: float = 1.0
var w_board_control: float = 1.0
var w_threat: float = 1.0

## Search depth (configurable per difficulty).
var search_depth: int = 2

## Computation time budget in milliseconds. Iterative deepening returns
## best move found so far if this budget is exceeded.
var computation_time_budget_ms: int = 200

## Terminal position score magnitude.
const TERMINAL_SCORE: float = 10000.0


# --- Personality Types ---

enum Personality { BALANCED, DEFENSIVE, AGGRESSIVE, TACTICAL, ERRATIC }

## Personality weight profiles: { material, king_freedom, king_proximity, board_control, threat }
const PERSONALITY_WEIGHTS: Dictionary = {
	Personality.BALANCED:   { "material": 1.0, "king_freedom": 1.0, "king_proximity": 1.0, "board_control": 1.0, "threat": 1.0 },
	Personality.DEFENSIVE:  { "material": 0.8, "king_freedom": 1.5, "king_proximity": 0.7, "board_control": 1.2, "threat": 0.6 },
	Personality.AGGRESSIVE: { "material": 1.3, "king_freedom": 0.7, "king_proximity": 1.4, "board_control": 0.8, "threat": 1.5 },
	Personality.TACTICAL:   { "material": 1.0, "king_freedom": 1.0, "king_proximity": 0.8, "board_control": 1.3, "threat": 1.4 },
	Personality.ERRATIC:    { "material": 1.0, "king_freedom": 1.0, "king_proximity": 1.0, "board_control": 1.0, "threat": 1.0 },
}


# --- Difficulty Tables ---

## Search depth per difficulty level (1-7).
const DEPTH_TABLE: Array[int] = [1, 1, 2, 2, 3, 4, 5]

## Mistake chance per difficulty level (1-7).
const MISTAKE_CHANCE_TABLE: Array[float] = [0.35, 0.25, 0.18, 0.12, 0.06, 0.02, 0.0]

## Mistake pool fraction per difficulty level (1-7) — how deep into ranked list.
const MISTAKE_POOL_TABLE: Array[float] = [0.6, 0.5, 0.4, 0.3, 0.3, 0.3, 0.0]

## Think time min per difficulty level (1-7) in seconds.
const THINK_TIME_MIN_TABLE: Array[float] = [0.5, 0.5, 1.0, 1.0, 1.5, 1.5, 2.0]

## Think time max per difficulty level (1-7) in seconds.
const THINK_TIME_MAX_TABLE: Array[float] = [1.5, 1.5, 2.0, 2.0, 3.0, 3.0, 4.0]

## Chance for erratic personality to swap top move with a random top-50% move.
var erratic_disruption_chance: float = 0.30


# --- Difficulty / Personality State ---

## Current difficulty level (1-7).
var difficulty: int = 1

## Current personality type.
var personality: int = Personality.BALANCED

## Mistake chance for current difficulty.
var _mistake_chance: float = 0.35

## Mistake pool fraction for current difficulty.
var _mistake_pool_fraction: float = 0.6

## Think time range for current difficulty.
var _think_time_min: float = 0.5
var _think_time_max: float = 1.5


# --- Internal State ---

## Reference to the Board Rules Engine. Set via configure() or found via Autoload.
var _board_rules: Node = null

## The side the AI plays (BoardRules.Side enum value).
var _ai_side: int = -1

## Best move found during iterative deepening.
var _best_move_so_far: Dictionary = {}

## Time when computation started (for budget enforcement).
var _computation_start_ms: int = 0

## Whether the time budget has been exceeded.
var _budget_exceeded: bool = false

## Cached enum values to avoid repeated lookups.
var _SIDE_ATTACKER: int = -1
var _SIDE_DEFENDER: int = -1
var _PIECE_NONE: int = -1
var _PIECE_ATTACKER: int = -1
var _PIECE_DEFENDER: int = -1
var _PIECE_KING: int = -1
var _WIN_NONE: int = -1
var _WIN_KING_ESCAPED: int = -1
var _WIN_KING_CAPTURED: int = -1
var _WIN_NO_LEGAL_MOVES: int = -1


# --- Public API ---

## Configure the AI with a board rules reference and side assignment.
## Optionally set difficulty (1-7) and personality type.
##
## Usage:
##   ai_system.configure(board_rules_node, BoardRules.Side.ATTACKER)
##   ai_system.configure(board_rules_node, BoardRules.Side.ATTACKER, 3, AISystem.Personality.DEFENSIVE)
func configure(board_rules: Node, ai_side: int, p_difficulty: int = -1, p_personality: int = -1) -> void:
	_board_rules = board_rules
	_ai_side = ai_side
	_cache_enums()
	if p_difficulty >= 1:
		apply_difficulty(p_difficulty)
	if p_personality >= 0:
		apply_personality(p_personality)


## Apply a difficulty level (1-7). Sets search depth, mistake chance, and think time.
##
## Usage:
##   ai_system.apply_difficulty(3)
func apply_difficulty(level: int) -> void:
	difficulty = clampi(level, 1, 7)
	var idx := difficulty - 1
	search_depth = DEPTH_TABLE[idx]
	_mistake_chance = MISTAKE_CHANCE_TABLE[idx]
	_mistake_pool_fraction = MISTAKE_POOL_TABLE[idx]
	_think_time_min = THINK_TIME_MIN_TABLE[idx]
	_think_time_max = THINK_TIME_MAX_TABLE[idx]


## Apply a personality type. Adjusts evaluation weights.
##
## Usage:
##   ai_system.apply_personality(AISystem.Personality.AGGRESSIVE)
func apply_personality(p_type: int) -> void:
	personality = p_type
	if PERSONALITY_WEIGHTS.has(p_type):
		var weights: Dictionary = PERSONALITY_WEIGHTS[p_type]
		w_material = weights.material
		w_king_freedom = weights.king_freedom
		w_king_proximity = weights.king_proximity
		w_board_control = weights.board_control
		w_threat = weights.threat


## Return the think time (seconds) for the current difficulty.
## Randomized between min and max for natural feel.
func get_think_time() -> float:
	return randf_range(_think_time_min, _think_time_max)


## Select the best move for the AI's side using minimax with alpha-beta pruning
## and iterative deepening. Returns a dictionary with "from" and "to" keys,
## or an empty dictionary if no legal moves exist.
##
## Usage:
##   var move := ai_system.select_move()
##   if not move.is_empty():
##       board_rules.submit_move(move.from, move.to)
func select_move() -> Dictionary:
	if _board_rules == null:
		push_warning("AISystem: No board rules configured")
		return {}

	var legal_moves: Array[Dictionary] = _board_rules.get_all_legal_moves(_ai_side)

	if legal_moves.is_empty():
		return {}

	# Single legal move — skip evaluation
	if legal_moves.size() == 1:
		return legal_moves[0]

	# --- Layer 1: Core Evaluator — score all moves via iterative deepening ---
	_computation_start_ms = Time.get_ticks_msec()
	_budget_exceeded = false

	# Score each move: Array of { move: Dictionary, score: float }
	var scored_moves: Array[Dictionary] = []
	for move in legal_moves:
		scored_moves.append({"move": move, "score": -INF})

	# Set initial fallback
	_best_move_so_far = legal_moves[0]

	for depth in range(1, search_depth + 1):
		if _budget_exceeded:
			break

		var ordered_moves := _order_moves(legal_moves)

		for i in ordered_moves.size():
			if _check_budget():
				break

			var move: Dictionary = ordered_moves[i]
			var sim := _simulate_move(move.from, move.to)

			var score: float
			if sim.win != _WIN_NONE:
				score = _score_terminal(sim.win, 0)
			else:
				score = _minimax(depth - 1, false, -INF, INF, 1)

			_undo_move(sim)

			# Update score for this move in scored_moves
			for entry in scored_moves:
				if entry.move.from == move.from and entry.move.to == move.to:
					entry.score = score
					break

		if not _budget_exceeded:
			# Sort by score descending after each completed depth
			scored_moves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return a.score > b.score
			)
			_best_move_so_far = scored_moves[0].move

	# Ensure sorted after final depth
	scored_moves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.score > b.score
	)

	# --- Layer 2: Personality post-processing ---
	var selected: Dictionary = _apply_personality_and_difficulty(scored_moves)
	return selected


## Evaluate a board position from the AI's perspective. Returns a float score.
## Exposed for testing.
func evaluate_position() -> float:
	return _evaluate()


## Return whether the time budget was exceeded during the last select_move() call.
func was_budget_exceeded() -> bool:
	return _budget_exceeded


# --- Internal: Personality & Difficulty ---

## Apply erratic disruption, then difficulty-based mistake injection.
## Returns the final selected move from the ranked move list.
func _apply_personality_and_difficulty(scored_moves: Array[Dictionary]) -> Dictionary:
	if scored_moves.is_empty():
		return {}

	if scored_moves.size() == 1:
		return scored_moves[0].move

	var candidates := scored_moves

	# Erratic disruption: swap top move with random from top 50%
	if personality == Personality.ERRATIC and randf() < erratic_disruption_chance:
		var pool_size := maxi(1, ceili(candidates.size() * 0.5))
		var swap_idx := randi_range(0, pool_size - 1)
		if swap_idx != 0:
			var temp: Dictionary = candidates[0]
			candidates[0] = candidates[swap_idx]
			candidates[swap_idx] = temp

	# Difficulty mistake injection
	if _mistake_chance > 0.0 and randf() < _mistake_chance:
		var pool_size := maxi(1, ceili(candidates.size() * _mistake_pool_fraction))
		# Filter out terminal-loss moves from the mistake pool
		var safe_pool: Array[Dictionary] = []
		for i in mini(pool_size, candidates.size()):
			if candidates[i].score > -TERMINAL_SCORE + 100:
				safe_pool.append(candidates[i])
		if not safe_pool.is_empty():
			var pick := safe_pool[randi_range(0, safe_pool.size() - 1)]
			return pick.move

	# No mistake — return the top-ranked move
	return candidates[0].move


# --- Internal: Minimax ---

func _minimax(depth: int, is_maximizing: bool, alpha: float, beta: float, ply: int) -> float:
	if _check_budget():
		return _evaluate()

	if depth == 0:
		return _evaluate()

	var side: int = _ai_side if is_maximizing else _opponent_side()
	var legal_moves: Array[Dictionary] = _board_rules.get_all_legal_moves(side)

	if legal_moves.is_empty():
		# No legal moves — this side loses
		if is_maximizing:
			return -TERMINAL_SCORE + ply  # AI loses (prefer later losses)
		else:
			return TERMINAL_SCORE - ply  # Opponent loses (prefer sooner wins)

	var ordered := _order_moves(legal_moves)

	if is_maximizing:
		var max_eval := -INF
		for move in ordered:
			if _check_budget():
				break
			var sim := _simulate_move(move.from, move.to)
			var eval_score: float
			if sim.win != _WIN_NONE:
				eval_score = _score_terminal(sim.win, ply)
			else:
				eval_score = _minimax(depth - 1, false, alpha, beta, ply + 1)
			_undo_move(sim)
			max_eval = maxf(max_eval, eval_score)
			alpha = maxf(alpha, eval_score)
			if beta <= alpha:
				break
		return max_eval
	else:
		var min_eval := INF
		for move in ordered:
			if _check_budget():
				break
			var sim := _simulate_move(move.from, move.to)
			var eval_score: float
			if sim.win != _WIN_NONE:
				eval_score = _score_terminal(sim.win, ply)
			else:
				eval_score = _minimax(depth - 1, true, alpha, beta, ply + 1)
			_undo_move(sim)
			min_eval = minf(min_eval, eval_score)
			beta = minf(beta, eval_score)
			if beta <= alpha:
				break
		return min_eval


# --- Internal: Evaluation ---

func _evaluate() -> float:
	var material := _eval_material()
	var king_freedom := _eval_king_freedom()
	var king_proximity := _eval_king_proximity()
	var board_control := _eval_board_control()
	var threat := _eval_threat()

	return (w_material * material
		+ w_king_freedom * king_freedom
		+ w_king_proximity * king_proximity
		+ w_board_control * board_control
		+ w_threat * threat)


func _eval_material() -> float:
	var friendly_count: int = _board_rules.get_piece_count(_ai_side)
	var enemy_count: int = _board_rules.get_piece_count(_opponent_side())
	return float(friendly_count - enemy_count)


func _eval_king_freedom() -> float:
	var king_pos: Vector2i = _board_rules._king_pos
	if king_pos == Vector2i(-1, -1):
		return 0.0

	var king_moves: Array[Vector2i] = _board_rules.get_legal_moves(king_pos)
	# Max possible moves for king on 7x7 = 12 (center, unblocked)
	var max_moves := float((_board_rules.board_size - 1) * 2)
	var freedom := float(king_moves.size()) / max_moves

	# Attacker wants low freedom, Defender wants high freedom
	if _ai_side == _SIDE_ATTACKER:
		return -freedom
	else:
		return freedom


func _eval_king_proximity() -> float:
	var king_pos: Vector2i = _board_rules._king_pos
	if king_pos == Vector2i(-1, -1):
		return 0.0

	var corners: Array[Vector2i] = _board_rules.corner_positions
	var min_dist := 999
	for corner in corners:
		var dist := absi(king_pos.x - corner.x) + absi(king_pos.y - corner.y)
		min_dist = mini(min_dist, dist)

	var max_dist := float(_board_rules.board_size - 1)  # Max Manhattan distance to any corner
	var proximity := 1.0 - (float(min_dist) / max_dist)

	# Attacker wants low proximity (King far from corners), Defender wants high
	if _ai_side == _SIDE_ATTACKER:
		return -proximity
	else:
		return proximity


func _eval_board_control() -> float:
	var king_pos: Vector2i = _board_rules._king_pos
	if king_pos == Vector2i(-1, -1):
		return 0.0

	if _ai_side == _SIDE_ATTACKER:
		# Control zone = 8 cells around King
		var zone_count := 0
		var friendly_in_zone := 0
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var pos := king_pos + Vector2i(dx, dy)
				if _board_rules.is_in_bounds(pos):
					zone_count += 1
					if _board_rules.get_piece(pos) == _PIECE_ATTACKER:
						friendly_in_zone += 1
		if zone_count == 0:
			return 0.0
		return float(friendly_in_zone) / float(zone_count)
	else:
		# Control zone = corner-adjacent corridors (edge rows/cols minus corners)
		var board_sz: int = _board_rules.board_size
		var max_idx: int = board_sz - 1
		var zone_cells: Array[Vector2i] = []
		for i in range(1, max_idx):
			zone_cells.append(Vector2i(0, i))      # Top row
			zone_cells.append(Vector2i(max_idx, i)) # Bottom row
			zone_cells.append(Vector2i(i, 0))       # Left col
			zone_cells.append(Vector2i(i, max_idx)) # Right col
		var friendly_in_zone := 0
		for pos in zone_cells:
			var piece: int = _board_rules.get_piece(pos)
			if piece == _PIECE_DEFENDER or piece == _PIECE_KING:
				friendly_in_zone += 1
		if zone_cells.is_empty():
			return 0.0
		return float(friendly_in_zone) / float(zone_cells.size())


func _eval_threat() -> float:
	var king_pos: Vector2i = _board_rules._king_pos
	if king_pos == Vector2i(-1, -1):
		return 0.0

	# King-adjacent attacker count (cheap — already computed by BoardRules)
	var king_adj_attackers: int = _board_rules.get_king_threat_count()

	# Lightweight capture threat estimate: count enemy pieces that are
	# adjacent to a friendly piece with a hostile square behind them.
	# This avoids simulating every legal move during evaluation.
	var capture_threats := 0
	var directions: Array[Vector2i] = _board_rules.directions
	var board_sz: int = _board_rules.board_size
	for row in board_sz:
		for col in board_sz:
			var pos := Vector2i(row, col)
			var piece: int = _board_rules.get_piece(pos)
			if piece == _PIECE_NONE:
				continue
			# Check if this is an enemy piece
			var is_enemy := false
			if _ai_side == _SIDE_ATTACKER:
				is_enemy = (piece == _PIECE_DEFENDER)  # Don't count King (4-sided capture)
			else:
				is_enemy = (piece == _PIECE_ATTACKER)
			if not is_enemy:
				continue
			# Check each axis for a flanking opportunity
			for dir in directions:
				var side_a := pos + dir
				var side_b := pos - dir
				if not _board_rules.is_in_bounds(side_a) or not _board_rules.is_in_bounds(side_b):
					continue
				var pa: int = _board_rules.get_piece(side_a)
				var pb: int = _board_rules.get_piece(side_b)
				# One side has a friendly piece, the other is empty (could move there)
				var friendly_a := _piece_is_friendly(pa)
				var friendly_b := _piece_is_friendly(pb)
				if (friendly_a and pb == _PIECE_NONE) or (friendly_b and pa == _PIECE_NONE):
					capture_threats += 1
					break  # Count each threatened piece once

	var raw_score: float = float(capture_threats) * 0.5 + float(king_adj_attackers) * 0.3

	# Attacker wants high threat, Defender wants low
	if _ai_side == _SIDE_ATTACKER:
		return raw_score
	else:
		return -raw_score


func _piece_is_friendly(piece: int) -> bool:
	if _ai_side == _SIDE_ATTACKER:
		return piece == _PIECE_ATTACKER
	return piece == _PIECE_DEFENDER or piece == _PIECE_KING


# --- Internal: Terminal Scoring ---

func _score_terminal(win_reason: int, ply: int) -> float:
	if win_reason == _WIN_KING_ESCAPED:
		if _ai_side == _SIDE_DEFENDER:
			return TERMINAL_SCORE - ply
		else:
			return -TERMINAL_SCORE + ply
	elif win_reason == _WIN_KING_CAPTURED:
		if _ai_side == _SIDE_ATTACKER:
			return TERMINAL_SCORE - ply
		else:
			return -TERMINAL_SCORE + ply
	elif win_reason == _WIN_NO_LEGAL_MOVES:
		# The side that has no moves loses
		# At this point we need to check who lost — the side that just moved wins
		# This is called after submit_move, so the losing side is the new active side
		var loser: int = _board_rules.get_active_side()
		if loser != _ai_side:
			return TERMINAL_SCORE - ply
		else:
			return -TERMINAL_SCORE + ply
	return 0.0


# --- Internal: Move Simulation ---

## Simulate a move on the real board and return undo data.
## This modifies the board state — call _undo_move() to restore it.
func _simulate_move(from: Vector2i, to: Vector2i) -> Dictionary:
	var piece: int = _board_rules.get_piece(from)
	var prev_active_side: int = _board_rules._active_side
	var prev_king_pos: Vector2i = _board_rules._king_pos
	var prev_match_active: bool = _board_rules._match_active
	var prev_winner: int = _board_rules._winner
	var prev_win_reason: int = _board_rules._win_reason
	var prev_move_count: int = _board_rules._move_count

	# Execute the move directly on the grid (bypassing signals for performance)
	_board_rules._grid[from.x][from.y] = _PIECE_NONE
	_board_rules._grid[to.x][to.y] = piece

	if piece == _PIECE_KING:
		_board_rules._king_pos = to

	_board_rules._move_count += 1

	# Check win conditions
	var win: int = _WIN_NONE

	# King escape
	if piece == _PIECE_KING and _board_rules.get_tile_type(to) == _board_rules.TileType.CORNER:
		win = _WIN_KING_ESCAPED
		_board_rules._match_active = false
		_board_rules._winner = _SIDE_DEFENDER
		_board_rules._win_reason = win

	# Captures
	var captures: Array[Vector2i] = []
	var captured_pieces: Array[int] = []
	if win == _WIN_NONE:
		captures = _board_rules._detect_captures(to, piece)
		for cap_pos in captures:
			captured_pieces.append(_board_rules.get_piece(cap_pos))
			_board_rules._grid[cap_pos.x][cap_pos.y] = _PIECE_NONE

		# King capture
		if win == _WIN_NONE and _board_rules._is_king_captured():
			win = _WIN_KING_CAPTURED
			_board_rules._match_active = false
			_board_rules._winner = _SIDE_ATTACKER
			_board_rules._win_reason = win

	# Turn switch
	if win == _WIN_NONE:
		_board_rules._active_side = _SIDE_DEFENDER if _board_rules._active_side == _SIDE_ATTACKER else _SIDE_ATTACKER

		# No legal moves check
		if _board_rules.get_all_legal_moves(_board_rules._active_side).is_empty():
			win = _WIN_NO_LEGAL_MOVES
			_board_rules._match_active = false
			_board_rules._winner = _SIDE_DEFENDER if _board_rules._active_side == _SIDE_ATTACKER else _SIDE_ATTACKER
			_board_rules._win_reason = win

	return {
		"from": from,
		"to": to,
		"piece": piece,
		"captures": captures,
		"captured_pieces": captured_pieces,
		"prev_active_side": prev_active_side,
		"prev_king_pos": prev_king_pos,
		"prev_match_active": prev_match_active,
		"prev_winner": prev_winner,
		"prev_win_reason": prev_win_reason,
		"prev_move_count": prev_move_count,
		"win": win,
	}


func _undo_move(sim: Dictionary) -> void:
	# Restore piece to original position
	_board_rules._grid[sim.to.x][sim.to.y] = _PIECE_NONE
	_board_rules._grid[sim.from.x][sim.from.y] = sim.piece

	# Restore captures
	for i in sim.captures.size():
		var cap_pos: Vector2i = sim.captures[i]
		_board_rules._grid[cap_pos.x][cap_pos.y] = sim.captured_pieces[i]

	# Restore state
	_board_rules._active_side = sim.prev_active_side
	_board_rules._king_pos = sim.prev_king_pos
	_board_rules._match_active = sim.prev_match_active
	_board_rules._winner = sim.prev_winner
	_board_rules._win_reason = sim.prev_win_reason
	_board_rules._move_count = sim.prev_move_count


# --- Internal: Move Ordering ---

func _order_moves(moves: Array[Dictionary]) -> Array[Dictionary]:
	# Simple heuristic: prioritize captures and King-adjacent moves
	var scored: Array[Dictionary] = []
	for move in moves:
		var priority := 0

		# Check if this move would capture
		var piece: int = _board_rules.get_piece(move.from)
		# Quick capture check by simulating
		var captures: Array[Vector2i] = _board_rules._detect_captures(move.to, piece)
		priority += captures.size() * 10

		# Moves adjacent to King
		var king_pos: Vector2i = _board_rules._king_pos
		var dist := absi(move.to.x - king_pos.x) + absi(move.to.y - king_pos.y)
		if dist <= 1:
			priority += 5

		# King moving toward corner (if this is King)
		if piece == _PIECE_KING:
			for corner in _board_rules.corner_positions:
				var corner_dist := absi(move.to.x - corner.x) + absi(move.to.y - corner.y)
				if corner_dist <= 2:
					priority += 8

		scored.append({"move": move, "priority": priority})

	# Sort by priority descending
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.priority > b.priority
	)

	var result: Array[Dictionary] = []
	for entry in scored:
		result.append(entry.move)
	return result


# --- Internal: Helpers ---

func _opponent_side() -> int:
	return _SIDE_DEFENDER if _ai_side == _SIDE_ATTACKER else _SIDE_ATTACKER


func _check_budget() -> bool:
	if _budget_exceeded:
		return true
	var elapsed := Time.get_ticks_msec() - _computation_start_ms
	if elapsed > computation_time_budget_ms:
		_budget_exceeded = true
		return true
	return false


func _cache_enums() -> void:
	_SIDE_ATTACKER = _board_rules.Side.ATTACKER
	_SIDE_DEFENDER = _board_rules.Side.DEFENDER
	_PIECE_NONE = _board_rules.PieceType.NONE
	_PIECE_ATTACKER = _board_rules.PieceType.ATTACKER
	_PIECE_DEFENDER = _board_rules.PieceType.DEFENDER
	_PIECE_KING = _board_rules.PieceType.KING
	_WIN_NONE = _board_rules.WinReason.NONE
	_WIN_KING_ESCAPED = _board_rules.WinReason.KING_ESCAPED
	_WIN_KING_CAPTURED = _board_rules.WinReason.KING_CAPTURED
	_WIN_NO_LEGAL_MOVES = _board_rules.WinReason.NO_LEGAL_MOVES
