## Tutorial System — Guided first match for the Prologue.
##
## Loads the tutorial step data, constrains Board UI input, submits scripted
## AI moves, and displays narrator text between steps. Activates only during
## Prologue match 1 and deactivates after the King escapes in step 8.
##
## Architecture: Feature Layer (ADR-0001). Depends on Board Rules, Board UI,
## Dialogue System, Campaign System.
## See: design/gdd/tutorial-system.md
extends Node


# --- Signals ---

## Emitted when the tutorial sequence is complete.
signal tutorial_complete()


# --- Constants ---

const DATA_PATH: String = "res://assets/data/tutorial/tutorial_steps.json"


# --- State ---

## Whether the tutorial is currently active.
var _active: bool = false

## Loaded step data from JSON.
var _steps: Array = []

## Board layout data from JSON.
var _board_layout: Dictionary = {}

## Current step index (0-based).
var _current_step: int = 0

## References to systems (set during activate).
var _board_rules: Node = null
var _board_ui: Node = null
var _dialogue: Node = null

## Whether we are waiting for the player to dismiss narrator text.
var _awaiting_narrator_dismiss: bool = false

## Whether we are waiting for the player to make a move.
var _awaiting_player_move: bool = false

## Whether we are waiting for an AI move animation to finish.
var _awaiting_ai_animation: bool = false


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_load_data()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Check if the tutorial is currently active.
func is_active() -> bool:
	return _active


## Activate the tutorial. Called by Campaign System for Prologue match 1.
## Sets up the simplified board and begins step 1.
##
## Usage:
##   TutorialSystem.activate(board_rules, board_ui)
func activate(board_rules: Node, board_ui: Node) -> void:
	if _steps.is_empty():
		push_warning("TutorialSystem: No step data loaded")
		return

	_board_rules = board_rules
	_board_ui = board_ui
	_dialogue = get_node_or_null("/root/DialogueSystem")
	_active = true
	_current_step = 0
	_awaiting_narrator_dismiss = false
	_awaiting_player_move = false
	_awaiting_ai_animation = false

	# Set up the simplified tutorial board
	_setup_tutorial_board()

	# Connect signals
	if _board_ui != null:
		if not _board_ui.move_submitted.is_connected(_on_player_move):
			_board_ui.move_submitted.connect(_on_player_move)
	if _board_rules != null:
		if not _board_rules.match_ended.is_connected(_on_match_ended):
			_board_rules.match_ended.connect(_on_match_ended)

	# Begin the first step
	_begin_step()


## Deactivate the tutorial and clean up.
func deactivate() -> void:
	_active = false
	_awaiting_narrator_dismiss = false
	_awaiting_player_move = false
	_awaiting_ai_animation = false

	if _board_ui != null:
		_board_ui.clear_tutorial_constraints()
		if _board_ui.move_submitted.is_connected(_on_player_move):
			_board_ui.move_submitted.disconnect(_on_player_move)
	if _board_rules != null:
		if _board_rules.match_ended.is_connected(_on_match_ended):
			_board_rules.match_ended.disconnect(_on_match_ended)

	_board_rules = null
	_board_ui = null


# ---------------------------------------------------------------------------
# Step Execution
# ---------------------------------------------------------------------------

func _begin_step() -> void:
	if _current_step >= _steps.size():
		_complete_tutorial()
		return

	var step: Dictionary = _steps[_current_step]

	# Show narrator text
	var narrator_text: String = step.get("narratorText", "")
	if narrator_text != "":
		var narrator_key: String = step.get("narratorTextKey", "")
		_awaiting_narrator_dismiss = true
		_show_narrator_text(narrator_text, narrator_key)
	else:
		_after_narrator_dismissed()


func _after_narrator_dismissed() -> void:
	_awaiting_narrator_dismiss = false

	var step: Dictionary = _steps[_current_step]
	var player_action: Variant = step.get("playerAction")
	var ai_action: Variant = step.get("aiAction")

	if player_action != null and player_action is Dictionary:
		# Set turn to defender for player action
		_force_active_side(0)  # 0 = DEFENDER (player)
		_setup_player_constraints(player_action)
		_awaiting_player_move = true
	elif ai_action != null and ai_action is Dictionary:
		# AI-only step (like step 5 — being captured)
		_execute_ai_action(ai_action)
	else:
		# Narration-only step (step 1 intro, step 8 victory)
		_advance_step()


func _after_player_move() -> void:
	_awaiting_player_move = false

	if _board_ui != null:
		_board_ui.clear_tutorial_constraints()

	var step: Dictionary = _steps[_current_step]
	var ai_action: Variant = step.get("aiAction")

	if ai_action != null and ai_action is Dictionary:
		# Wait for move animation to finish, then do AI
		if _board_ui != null and _board_ui.is_animating():
			_board_ui.animations_finished.connect(_on_player_anim_done.bind(ai_action), CONNECT_ONE_SHOT)
		else:
			_execute_ai_action(ai_action)
	else:
		# No AI action — check for post-narrator or advance
		_check_step_completion()


func _on_player_anim_done(ai_action: Dictionary) -> void:
	_execute_ai_action(ai_action)


func _execute_ai_action(ai_action: Dictionary) -> void:
	var from_arr: Array = ai_action.get("from", [])
	var to_arr: Array = ai_action.get("to", [])
	if from_arr.size() < 2 or to_arr.size() < 2:
		_check_step_completion()
		return

	var from := Vector2i(int(from_arr[0]), int(from_arr[1]))
	var to := Vector2i(int(to_arr[0]), int(to_arr[1]))

	# Force attacker's turn for AI move
	_force_active_side(1)  # 1 = ATTACKER

	var result: Dictionary = _board_rules.submit_move(from, to)
	if not result.valid:
		push_warning("TutorialSystem: Scripted AI move failed: %s → %s (%s)" % [from, to, result.error])
		_check_step_completion()
		return

	# Wait for AI animation, then check completion
	_awaiting_ai_animation = true
	if _board_ui != null:
		_board_ui.populate_board()
		if _board_ui.is_animating():
			_board_ui.animations_finished.connect(_on_ai_anim_done, CONNECT_ONE_SHOT)
		else:
			_on_ai_anim_done()
	else:
		_on_ai_anim_done()


func _on_ai_anim_done() -> void:
	_awaiting_ai_animation = false
	_check_step_completion()


func _check_step_completion() -> void:
	var step: Dictionary = _steps[_current_step]

	# Check for post-action narrator text (e.g., step 5 "Like that.")
	var after_text: String = step.get("narratorTextAfter", "")
	if after_text != "":
		var after_key: String = step.get("narratorTextAfterKey", "")
		# Clear it so we don't re-show
		_steps[_current_step]["narratorTextAfter"] = ""
		_awaiting_narrator_dismiss = true
		_show_narrator_text(after_text, after_key)
		return

	_advance_step()


func _advance_step() -> void:
	_current_step += 1
	if _current_step >= _steps.size():
		_complete_tutorial()
		return
	_begin_step()


func _complete_tutorial() -> void:
	deactivate()
	tutorial_complete.emit()


# ---------------------------------------------------------------------------
# Narrator Display
# ---------------------------------------------------------------------------

func _show_narrator_text(text: String, text_key: String = "") -> void:
	# Create a narrator line dict compatible with DialogueOverlay
	var line: Dictionary = {
		"id": "tutorial_narrator",
		"opponent_id": "narrator",
		"speaker": "",
		"text": text,
		"textKey": text_key,
	}

	if _dialogue != null:
		_dialogue._current_lines = [line]
		_dialogue._current_line_index = 0
		_dialogue._active = true

	# Find the board's parent to add overlay
	var overlay_parent: Node = _board_ui.get_parent() if _board_ui != null else null
	if overlay_parent == null:
		overlay_parent = get_tree().root

	var DialogueOverlayScript: GDScript = preload("res://src/ui/dialogue_overlay.gd")
	var overlay: Control = DialogueOverlayScript.new()
	overlay_parent.add_child(overlay)
	overlay.completed.connect(_on_narrator_dismissed)


func _on_narrator_dismissed() -> void:
	if _awaiting_narrator_dismiss:
		_after_narrator_dismissed()


# ---------------------------------------------------------------------------
# Board Setup
# ---------------------------------------------------------------------------

func _setup_tutorial_board() -> void:
	if _board_rules == null or _board_layout.is_empty():
		return

	# Configure board with tutorial layout positions
	var king_arr: Array = _board_layout.get("king", [3, 3])
	_board_rules.king_start_pos = Vector2i(int(king_arr[0]), int(king_arr[1]))

	var defenders: Array[Vector2i] = []
	for d: Array in _board_layout.get("defenders", []):
		if d.size() >= 2:
			defenders.append(Vector2i(int(d[0]), int(d[1])))
	_board_rules.defender_start_positions = defenders

	var attackers: Array[Vector2i] = []
	for a: Array in _board_layout.get("attackers", []):
		if a.size() >= 2:
			attackers.append(Vector2i(int(a[0]), int(a[1])))
	_board_rules.attacker_start_positions = attackers

	# Start a real match with the tutorial layout
	_board_rules.start_match(_board_rules.MatchMode.STANDARD, _board_rules.Side.DEFENDER)

	if _board_ui != null:
		_board_ui.populate_board()


func _setup_player_constraints(player_action: Dictionary) -> void:
	if _board_ui == null:
		return

	var allowed: Array = []
	for piece_arr: Array in player_action.get("allowedPieces", []):
		if piece_arr.size() >= 2:
			allowed.append(Vector2i(int(piece_arr[0]), int(piece_arr[1])))

	var highlights: Array = []
	for hl_arr: Array in player_action.get("forcedHighlights", []):
		if hl_arr.size() >= 2:
			highlights.append(Vector2i(int(hl_arr[0]), int(hl_arr[1])))

	_board_ui.set_tutorial_constraints(allowed, highlights)


func _force_active_side(side: int) -> void:
	if _board_rules != null:
		_board_rules._active_side = side


# ---------------------------------------------------------------------------
# Signal Handlers
# ---------------------------------------------------------------------------

func _on_player_move(_from: Vector2i, _to: Vector2i) -> void:
	if not _active or not _awaiting_player_move:
		return
	# Player made a move — process it
	call_deferred("_after_player_move")


func _on_match_ended(_result: Dictionary) -> void:
	if not _active:
		return
	# Match ended (King escape) — complete tutorial
	_complete_tutorial()


# ---------------------------------------------------------------------------
# Data Loading
# ---------------------------------------------------------------------------

func _load_data() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("TutorialSystem: Data file not found at %s" % DATA_PATH)
		return

	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var err: Error = json.parse(json_text)
	if err != OK:
		push_error("TutorialSystem: Failed to parse tutorial data: %s" % json.get_error_message())
		return

	var data: Dictionary = json.data
	_board_layout = data.get("boardLayout", {})
	_steps = data.get("steps", [])
