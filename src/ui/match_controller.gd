## Match Controller — Orchestrates a single Fidchell match.
##
## Wires BoardRules, AISystem, and BoardUI together. Manages the turn loop:
## player taps pieces via BoardUI, AI responds on its turn, match ends
## with a result display. Created as root script of the Match scene.
##
## Architecture: Core Layer (ADR-0001). Depends on Board Rules, AI System, Board UI.
## See: design/gdd/board-ui.md, design/gdd/ai-system.md
##
## Usage (launched by SceneManager):
##   SceneManager.change_scene(&"match")
class_name MatchController
extends Control


# --- Configuration ---

## Opponent profile resource (set before match starts).
var opponent_profile: Resource = null

## Player's side assignment.
var player_side: int = 1  # Side.DEFENDER

## AI side (opposite of player).
var _ai_side: int = 0  # Side.ATTACKER


# --- Node References ---

var _board_ui: Control = null
var _turn_label: Label = null
var _opponent_label: Label = null
var _result_panel: PanelContainer = null
var _result_label: Label = null
var _ai_thinking_label: Label = null
var _play_again_button: Button = null
var _move_count_label: Label = null


# --- State ---

var _match_active: bool = false
var _ai_thinking: bool = false


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_ui()
	_start_match()


func _build_ui() -> void:
	# Root fills the screen
	set_anchors_preset(PRESET_FULL_RECT)

	# Background color
	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.18, 0.14, 0.10)
	add_child(bg)

	# Opponent info (top)
	var top_bar := _create_info_bar()
	top_bar.set_anchors_preset(PRESET_TOP_WIDE)
	top_bar.offset_bottom = 40.0
	add_child(top_bar)

	_opponent_label = Label.new()
	_opponent_label.text = _get_opponent_name()
	_opponent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_opponent_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	top_bar.add_child(_opponent_label)

	_ai_thinking_label = Label.new()
	_ai_thinking_label.text = "Thinking..."
	_ai_thinking_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ai_thinking_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	_ai_thinking_label.visible = false
	top_bar.add_child(_ai_thinking_label)

	# Board UI (center)
	var BoardUIScript: GDScript = preload("res://src/ui/board_ui.gd")
	_board_ui = BoardUIScript.new()
	_board_ui.set_anchors_preset(PRESET_FULL_RECT)
	_board_ui.offset_top = 45.0
	_board_ui.offset_bottom = -80.0
	add_child(_board_ui)

	# Bottom bar
	var bottom_bar := _create_info_bar()
	bottom_bar.set_anchors_preset(PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -75.0
	add_child(bottom_bar)

	# Turn indicator
	_turn_label = Label.new()
	_turn_label.text = "Your turn"
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	bottom_bar.add_child(_turn_label)

	# Move counter
	_move_count_label = Label.new()
	_move_count_label.text = "Move: 0"
	_move_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_move_count_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
	bottom_bar.add_child(_move_count_label)

	# Result panel (hidden until match ends)
	_result_panel = PanelContainer.new()
	_result_panel.set_anchors_preset(PRESET_CENTER)
	_result_panel.offset_left = -150.0
	_result_panel.offset_right = 150.0
	_result_panel.offset_top = -80.0
	_result_panel.offset_bottom = 80.0
	_result_panel.visible = false
	add_child(_result_panel)

	var result_vbox := VBoxContainer.new()
	result_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_panel.add_child(result_vbox)

	_result_label = Label.new()
	_result_label.text = ""
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	result_vbox.add_child(_result_label)

	_play_again_button = Button.new()
	_play_again_button.text = "Play Again"
	_play_again_button.pressed.connect(_on_play_again_pressed)
	result_vbox.add_child(_play_again_button)


func _create_info_bar() -> VBoxContainer:
	var bar := VBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	return bar


# ---------------------------------------------------------------------------
# Match Setup
# ---------------------------------------------------------------------------

func _start_match() -> void:
	var board_rules: Node = _get_board_rules()
	var ai_system: Node = _get_ai_system()

	# Determine sides
	_ai_side = 1 - player_side  # Opposite side

	# Start the match
	board_rules.start_match(board_rules.MatchMode.STANDARD, player_side)

	# Configure AI
	if opponent_profile != null:
		ai_system.configure(board_rules, _ai_side)
		opponent_profile.apply_to(ai_system)
	else:
		# Default: difficulty 1, erratic personality
		ai_system.configure(board_rules, _ai_side, 1, ai_system.Personality.ERRATIC)

	# Configure Board UI
	var config: Resource = null
	if ResourceLoader.exists("res://assets/data/ui/default_board_ui.tres"):
		config = load("res://assets/data/ui/default_board_ui.tres")
	_board_ui.configure(board_rules, config)

	# Connect match signals
	board_rules.turn_changed.connect(_on_turn_changed)
	board_rules.match_ended.connect(_on_match_ended)

	_match_active = true
	_update_turn_display()

	# If AI goes first (player is defender, attacker starts)
	if board_rules.get_active_side() == _ai_side:
		_start_ai_turn()


# ---------------------------------------------------------------------------
# Turn Management
# ---------------------------------------------------------------------------

func _on_turn_changed(new_active_side: int) -> void:
	_update_turn_display()
	_update_move_count()

	if new_active_side == _ai_side and _match_active:
		_start_ai_turn()


func _start_ai_turn() -> void:
	_ai_thinking = true
	_ai_thinking_label.visible = true
	_turn_label.text = "Opponent's turn"

	var ai_system: Node = _get_ai_system()
	var board_rules: Node = _get_board_rules()

	# Wait for think time (feels natural)
	var think_time: float = ai_system.get_think_time()
	await get_tree().create_timer(think_time).timeout

	if not _match_active:
		return

	# Wait for any ongoing animations to finish
	if _board_ui.is_animating():
		await _board_ui.animations_finished

	# Select and submit AI move
	var move: Dictionary = ai_system.select_move()
	_ai_thinking = false
	_ai_thinking_label.visible = false

	if not move.is_empty():
		board_rules.submit_move(move.from, move.to)


func _update_turn_display() -> void:
	var board_rules: Node = _get_board_rules()
	var active_side: int = board_rules.get_active_side()

	if active_side == player_side:
		_turn_label.text = "Your turn"
	else:
		_turn_label.text = "Opponent's turn"


func _update_move_count() -> void:
	var board_rules: Node = _get_board_rules()
	var move_count: int = board_rules.get_move_count()
	_move_count_label.text = "Move: " + str(move_count)


# ---------------------------------------------------------------------------
# Match End
# ---------------------------------------------------------------------------

func _on_match_ended(result: Dictionary) -> void:
	_match_active = false
	_ai_thinking = false
	_ai_thinking_label.visible = false

	# Wait for animations to finish
	if _board_ui.is_animating():
		await _board_ui.animations_finished

	# Brief pause before showing result
	await get_tree().create_timer(0.5).timeout

	_show_result(result)


func _show_result(result: Dictionary) -> void:
	var winner: int = result["winner"]
	var reason: int = result["reason"]
	var move_count: int = result["move_count"]

	var text: String = ""

	if winner == player_side:
		text = "Victory!\n"
	else:
		text = "Defeat\n"

	# Win reason
	var board_rules: Node = _get_board_rules()
	if reason == board_rules.WinReason.KING_ESCAPED:
		text += "The King escaped!\n"
	elif reason == board_rules.WinReason.KING_CAPTURED:
		text += "The King was captured!\n"
	elif reason == board_rules.WinReason.NO_LEGAL_MOVES:
		text += "No moves remaining\n"

	text += "Moves: " + str(move_count)

	_result_label.text = text
	_result_panel.visible = true
	_turn_label.text = "Match over"


func _on_play_again_pressed() -> void:
	_result_panel.visible = false

	# Disconnect old signals
	var board_rules: Node = _get_board_rules()
	if board_rules.turn_changed.is_connected(_on_turn_changed):
		board_rules.turn_changed.disconnect(_on_turn_changed)
	if board_rules.match_ended.is_connected(_on_match_ended):
		board_rules.match_ended.disconnect(_on_match_ended)

	_start_match()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _get_opponent_name() -> String:
	if opponent_profile != null and opponent_profile.character_name != "":
		return opponent_profile.character_name
	return "Opponent"


func _get_board_rules() -> Node:
	# Try autoload first, fall back to manual lookup
	if Engine.has_singleton("BoardRules"):
		return Engine.get_singleton("BoardRules")
	var node: Node = get_node_or_null("/root/BoardRules")
	if node != null:
		return node
	# For testing: find in tree
	return get_tree().root.get_node("BoardRules")


func _get_ai_system() -> Node:
	if Engine.has_singleton("AISystem"):
		return Engine.get_singleton("AISystem")
	var node: Node = get_node_or_null("/root/AISystem")
	if node != null:
		return node
	return get_tree().root.get_node("AISystem")
