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

## Debug: auto-play mode — both sides controlled by AI.
## Set to true via command line: --autoplay, or toggle in code.
var debug_autoplay: bool = false

## Debug: second AI for player side in auto-play mode.
var _player_ai: Node = null

## Debug: fast autoplay mode (reduced timings).
var _fast_autoplay: bool = false

## Debug: match counter for auto-play.
var _autoplay_match_count: int = 0

## Debug: total matches to auto-play (0 = infinite).
var _autoplay_max_matches: int = 3

## Whether this match is part of a campaign (affects return behavior).
var _campaign_mode: bool = false

## Match type from campaign schedule ("standard" or "scripted").
var _match_type: String = "standard"

## Last match result (for passing back to campaign map).
var _last_match_result: Dictionary = {}


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Load settings from scene data
	var scene_manager: Node = get_node_or_null("/root/SceneManager")

	# Check for --autoplay command line flag or file-based trigger
	if OS.get_cmdline_args().has("--autoplay") or OS.get_cmdline_user_args().has("--autoplay"):
		debug_autoplay = true
		print("[MATCH] Auto-play mode enabled (CLI)")
	elif scene_manager != null and scene_manager.autoplay_config.get("enabled", false):
		debug_autoplay = true
		_fast_autoplay = scene_manager.autoplay_config.get("fast", false)
		print("[MATCH] Auto-play mode enabled (cfg file, fast=%s)" % str(_fast_autoplay))
	if scene_manager != null:
		if scene_manager.scene_data.has("opponent_profile_path"):
			var path: String = scene_manager.scene_data["opponent_profile_path"]
			if ResourceLoader.exists(path):
				opponent_profile = load(path)
		_campaign_mode = scene_manager.scene_data.get("campaign_mode", false)
		_match_type = scene_manager.scene_data.get("match_type", "standard")
		scene_manager.scene_data = {}

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
	var is_scripted: bool = (_match_type == "scripted")

	# Determine sides
	_ai_side = 1 - player_side  # Opposite side

	# Start the match
	board_rules.start_match(board_rules.MatchMode.STANDARD, player_side)

	if debug_autoplay or is_scripted:
		_autoplay_match_count += 1
		print("[MATCH] === Starting match #%d%s ===" % [
			_autoplay_match_count,
			" (SCRIPTED)" if is_scripted else ""])
		print("[MATCH] Player side: %s | AI side: %s" % [
			"DEFENDER" if player_side == 1 else "ATTACKER",
			"ATTACKER" if _ai_side == 0 else "DEFENDER"])

	# Configure AI (opponent) — strong attacker for scripted mode
	if is_scripted:
		ai_system.configure(board_rules, _ai_side, 3, ai_system.Personality.TACTICAL)
	elif opponent_profile != null:
		ai_system.configure(board_rules, _ai_side)
		opponent_profile.apply_to(ai_system)
	else:
		# Default: difficulty 1, erratic personality
		ai_system.configure(board_rules, _ai_side, 1, ai_system.Personality.ERRATIC)

	# Configure second AI for auto-play or scripted mode (player side)
	if debug_autoplay or is_scripted:
		if _player_ai == null:
			var AISystemScript: GDScript = preload("res://src/core/ai_system.gd")
			_player_ai = AISystemScript.new()
			_player_ai.name = "PlayerAI"
			add_child(_player_ai)
		if is_scripted:
			# Weak defender: low difficulty, high mistakes — attacker should win
			_player_ai.configure(board_rules, player_side, 1, _player_ai.Personality.ERRATIC)
			_player_ai._mistake_chance = 0.5
			print("[MATCH] Scripted: Attacker AI difficulty 3 Tactical, Defender AI difficulty 1 Erratic (50%% mistakes)")
		else:
			# Scale player AI difficulty by chapter to simulate a learning player
			var campaign: Node = get_node_or_null("/root/CampaignSystem")
			var chapter_idx: int = campaign.current_chapter if campaign != null else 0
			var player_difficulty: int = clampi(chapter_idx + 1, 1, 5)
			var player_mistake: float = maxf(0.20 - chapter_idx * 0.03, 0.05)
			_player_ai.configure(board_rules, player_side, player_difficulty, _player_ai.Personality.BALANCED)
			_player_ai._mistake_chance = player_mistake
			print("[MATCH] Player AI: difficulty %d, Balanced (mistakes %.0f%%)" % [player_difficulty, player_mistake * 100])
			print("[MATCH] Opponent AI: %s" % (opponent_profile.character_name if opponent_profile != null else "default"))

	# Configure Board UI
	var config: Resource = null
	if ResourceLoader.exists("res://assets/data/ui/default_board_ui.tres"):
		config = load("res://assets/data/ui/default_board_ui.tres")
	_board_ui.configure(board_rules, config)

	# Wire Board UI to Audio System for piece select/deselect SFX
	# and start chapter-appropriate match music + ambient
	var audio: Node = get_node_or_null("/root/AudioSystem")
	if audio != null:
		audio.connect_board_ui(_board_ui)
		var campaign: Node = get_node_or_null("/root/CampaignSystem")
		if campaign != null:
			var chapter_idx: int = campaign.current_chapter
			var is_final_boss: bool = _match_type == "standard" and chapter_idx == 4 and opponent_profile != null and opponent_profile.character_name == "Murchadh"
			if is_final_boss:
				audio.play_music("match_final_boss")
			else:
				audio.play_music("match_chapter_%d" % chapter_idx)
			audio.play_ambient_for_chapter(chapter_idx)
		audio.play_sfx("board_setup")

	# Connect match signals
	board_rules.turn_changed.connect(_on_turn_changed)
	board_rules.match_ended.connect(_on_match_ended)

	# Debug logging for signals
	if debug_autoplay or is_scripted:
		if not board_rules.piece_moved.is_connected(_debug_on_piece_moved):
			board_rules.piece_moved.connect(_debug_on_piece_moved)
		if not board_rules.piece_captured.is_connected(_debug_on_piece_captured):
			board_rules.piece_captured.connect(_debug_on_piece_captured)
		if not board_rules.king_threatened.is_connected(_debug_on_king_threatened):
			board_rules.king_threatened.connect(_debug_on_king_threatened)

	_match_active = true

	# Tutorial mode: delegate to TutorialSystem (skip in autoplay)
	if _match_type == "tutorial":
		if debug_autoplay:
			print("[MATCH] Skipping tutorial in autoplay — auto-completing as win")
			_match_active = false
			_last_match_result = {
				"winner": 1,  # Side.DEFENDER
				"reason": board_rules.WinReason.KING_ESCAPED,
				"move_count": 0,
				"pieces_remaining": { "attacker": 0, "defender": 0 },
			}
			await get_tree().create_timer(0.1).timeout
			if _campaign_mode:
				_return_to_campaign()
			return
		var tutorial: Node = get_node_or_null("/root/TutorialSystem")
		if tutorial != null:
			tutorial.tutorial_complete.connect(_on_tutorial_complete, CONNECT_ONE_SHOT)
			tutorial.activate(board_rules, _board_ui)
			_turn_label.text = ""
			return
		else:
			push_warning("MatchController: TutorialSystem not found, falling back to standard match")

	# Scripted mode: show "Watching..." instead of turn info
	if is_scripted:
		_turn_label.text = "Watching..."
	else:
		_update_turn_display()

	# If AI goes first (player is defender, attacker starts)
	if board_rules.get_active_side() == _ai_side:
		_start_ai_turn()
	elif debug_autoplay or is_scripted:
		_start_autoplay_turn()


# ---------------------------------------------------------------------------
# Turn Management
# ---------------------------------------------------------------------------

func _on_turn_changed(new_active_side: int) -> void:
	if _match_type != "scripted":
		_update_turn_display()
	_update_move_count()

	if not _match_active:
		return

	if new_active_side == _ai_side:
		_start_ai_turn()
	elif debug_autoplay or _match_type == "scripted":
		_start_autoplay_turn()


func _start_ai_turn() -> void:
	_ai_thinking = true
	_ai_thinking_label.visible = _match_type != "scripted"
	if _match_type != "scripted":
		_turn_label.text = "Opponent's turn"

	var ai_system: Node = _get_ai_system()
	var board_rules: Node = _get_board_rules()

	# Wait for think time — fast in scripted/fast-autoplay mode
	var think_time: float
	if _match_type == "scripted":
		think_time = 0.3
	elif _fast_autoplay:
		think_time = 0.05
	else:
		think_time = ai_system.get_think_time()
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
		if debug_autoplay:
			var side_name: String = "ATTACKER" if _ai_side == 0 else "DEFENDER"
			print("[MOVE] %s (opponent-ai): %s -> %s" % [side_name, move.from, move.to])
		board_rules.submit_move(move.from, move.to)
	else:
		if debug_autoplay:
			print("[MATCH] Opponent AI has no legal moves!")


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

func _on_tutorial_complete() -> void:
	_match_active = false
	var board_rules: Node = _get_board_rules()

	# Tutorial ends with King escape — build a win result
	_last_match_result = {
		"winner": 1,  # Side.DEFENDER (player wins tutorial)
		"reason": board_rules.WinReason.KING_ESCAPED,
		"move_count": board_rules.get_move_count(),
		"pieces_remaining": {
			"attacker": board_rules.get_piece_count(board_rules.Side.ATTACKER),
			"defender": board_rules.get_piece_count(board_rules.Side.DEFENDER),
		},
	}

	_turn_label.text = ""

	# Brief pause, then return to campaign
	await get_tree().create_timer(1.5).timeout

	if _campaign_mode:
		_return_to_campaign()
	else:
		_show_result(_last_match_result)


func _on_match_ended(result: Dictionary) -> void:
	_match_active = false
	_ai_thinking = false
	_ai_thinking_label.visible = false

	# Scripted mode: force attacker win regardless of actual outcome
	if _match_type == "scripted":
		var board_rules: Node = _get_board_rules()
		_last_match_result = {
			"winner": 0,  # Side.ATTACKER
			"reason": board_rules.WinReason.KING_CAPTURED,
			"move_count": result.get("move_count", 0),
			"pieces_remaining": result.get("pieces_remaining", {}),
		}

		# Wait for animations, brief pause, then auto-return
		if _board_ui.is_animating():
			await _board_ui.animations_finished
		await get_tree().create_timer(1.0).timeout

		_turn_label.text = "Defeat"
		await get_tree().create_timer(1.5).timeout
		_return_to_campaign()
		return

	_last_match_result = result

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

	var winner_name: String = "DEFENDER" if winner == 1 else "ATTACKER"
	var reason_names: Array = ["NONE", "KING_ESCAPED", "KING_CAPTURED", "NO_LEGAL_MOVES"]
	var reason_name: String = reason_names[reason] if reason < reason_names.size() else "UNKNOWN"

	if debug_autoplay:
		print("[MATCH] === Match #%d Result ===" % _autoplay_match_count)
		print("[MATCH] Winner: %s | Reason: %s | Moves: %d" % [winner_name, reason_name, move_count])
		if result.has("pieces_remaining"):
			var remaining: Dictionary = result["pieces_remaining"]
			print("[MATCH] Pieces remaining — Attacker: %d, Defender: %d" % [
				remaining["attacker"], remaining["defender"]])

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

	# Campaign mode: change button text
	if _campaign_mode:
		_play_again_button.text = "Continue"

	# Auto-play: continue after a brief pause
	if debug_autoplay:
		var result_delay: float = 0.3 if _fast_autoplay else 2.0
		if _campaign_mode:
			# Campaign: auto-return to campaign map
			print("[MATCH] Auto-returning to campaign map in %.1fs..." % result_delay)
			await get_tree().create_timer(result_delay).timeout
			_on_play_again_pressed()
		else:
			# Quick play: restart match (with limit)
			if _autoplay_max_matches > 0 and _autoplay_match_count >= _autoplay_max_matches:
				print("[MATCH] === Auto-play complete: %d matches played ===" % _autoplay_match_count)
				return
			print("[MATCH] Starting next match in %.1fs..." % result_delay)
			await get_tree().create_timer(result_delay).timeout
			_on_play_again_pressed()


func _return_to_campaign() -> void:
	var scene_manager: Node = get_node_or_null("/root/SceneManager")
	if scene_manager != null:
		scene_manager.scene_data = { "match_result": _last_match_result }
		visible = false
		scene_manager.change_scene(&"campaign_map")
		queue_free()


func _on_play_again_pressed() -> void:
	_result_panel.visible = false

	# Campaign mode: return to campaign map with the result
	if _campaign_mode:
		_return_to_campaign()
		return

	# Quick play / auto-play: restart match
	var board_rules: Node = _get_board_rules()
	if board_rules.turn_changed.is_connected(_on_turn_changed):
		board_rules.turn_changed.disconnect(_on_turn_changed)
	if board_rules.match_ended.is_connected(_on_match_ended):
		board_rules.match_ended.disconnect(_on_match_ended)

	_start_match()


# ---------------------------------------------------------------------------
# Debug: Auto-play
# ---------------------------------------------------------------------------

## Auto-play the player's turn using a second AI.
func _start_autoplay_turn() -> void:
	if _player_ai == null or not _match_active:
		return

	if _match_type != "scripted":
		_turn_label.text = "Auto-playing..."

	var board_rules: Node = _get_board_rules()

	# Short delay so animations can play — faster in scripted/fast mode
	var delay: float
	if _match_type == "scripted":
		delay = 0.2
	elif _fast_autoplay:
		delay = 0.05
	else:
		delay = 0.15
	await get_tree().create_timer(delay).timeout

	if not _match_active:
		return

	if _board_ui.is_animating():
		await _board_ui.animations_finished

	var move: Dictionary = _player_ai.select_move()

	if not move.is_empty():
		var side_name: String = "DEFENDER" if player_side == 1 else "ATTACKER"
		print("[MOVE] %s (player-ai): %s -> %s" % [side_name, move.from, move.to])
		board_rules.submit_move(move.from, move.to)
	else:
		print("[MATCH] Player AI has no legal moves!")


func _debug_on_piece_moved(piece_type: int, from_pos: Vector2i, to_pos: Vector2i) -> void:
	var type_name: String = ["NONE", "ATTACKER", "DEFENDER", "KING"][piece_type]
	print("[MOVE] %s moved: %s -> %s" % [type_name, from_pos, to_pos])


func _debug_on_piece_captured(piece_type: int, cell: Vector2i, captured_by: Vector2i) -> void:
	var type_name: String = ["NONE", "ATTACKER", "DEFENDER", "KING"][piece_type]
	print("[CAPTURE] %s captured at %s (by move to %s)" % [type_name, cell, captured_by])


func _debug_on_king_threatened(king_pos: Vector2i, threat_count: int) -> void:
	print("[THREAT] King at %s threatened by %d attackers!" % [king_pos, threat_count])


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
