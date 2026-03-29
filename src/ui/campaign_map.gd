## Campaign Map — Displays current chapter, opponent, and reputation.
##
## The hub screen between matches. Shows where the player is in the campaign,
## who their next opponent is, current reputation, and a "Challenge" button
## to start the next match. Handles the full match flow:
## campaign map → pre-dialogue → match → post-dialogue → reputation → campaign map.
##
## Architecture: Presentation Layer (ADR-0001).
## See: design/gdd/campaign-system.md, production/sprints/sprint-02.md (S2-09, S2-10)
extends Control


# --- UI References ---

var _chapter_label: Label = null
var _location_label: Label = null
var _opponent_label: Label = null
var _opponent_desc_label: Label = null
var _reputation_label: Label = null
var _progress_label: Label = null
var _history_label: Label = null
var _challenge_button: Button = null
var _status_label: Label = null

# --- Reputation Breakdown Panel ---
var _rep_panel: PanelContainer = null
var _rep_breakdown_label: Label = null
var _rep_continue_button: Button = null

# --- State ---

var _campaign: Node = null
var _dialogue: Node = null
var _reputation: Node = null
var _scene_manager: Node = null
var _match_result: Dictionary = {}
var _autoplay: bool = false


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_campaign = get_node_or_null("/root/CampaignSystem")
	_dialogue = get_node_or_null("/root/DialogueSystem")
	_reputation = get_node_or_null("/root/ReputationSystem")
	_scene_manager = get_node_or_null("/root/SceneManager")
	_autoplay = OS.get_cmdline_args().has("--autoplay") or OS.get_cmdline_user_args().has("--autoplay")

	# Register scenes
	if _scene_manager != null:
		_scene_manager.register_scene(&"match", "res://scenes/match/Match.tscn")
		_scene_manager.register_scene(&"campaign_map", "res://scenes/campaign/CampaignMap.tscn")
		_scene_manager.register_scene(&"menu", "res://scenes/menu/MainMenu.tscn")

	_build_ui()

	# Start new campaign if not active
	if _campaign != null and not _campaign.campaign_active:
		_campaign.start_new_campaign()

	_update_display()

	# Check if we're returning from a match (scene_data has result)
	if _scene_manager != null and _scene_manager.scene_data.has("match_result"):
		_match_result = _scene_manager.scene_data["match_result"]
		_scene_manager.scene_data = {}
		_handle_match_return()
	elif _scene_manager != null and _scene_manager.scene_data.has("show_narrator"):
		var narrator_id: String = _scene_manager.scene_data.get("narrator_id", "")
		_scene_manager.scene_data = {}
		if narrator_id != "":
			_show_narrator(narrator_id)
	elif _autoplay:
		_autoplay_challenge()


func _build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.10, 0.08, 0.05)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_CENTER)
	vbox.offset_left = -160.0
	vbox.offset_right = 160.0
	vbox.offset_top = -200.0
	vbox.offset_bottom = 200.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# Chapter info
	_chapter_label = Label.new()
	_chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chapter_label.add_theme_font_size_override("font_size", 24)
	_chapter_label.add_theme_color_override("font_color", Color(0.9, 0.82, 0.55))
	vbox.add_child(_chapter_label)

	_location_label = Label.new()
	_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_location_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
	vbox.add_child(_location_label)

	_add_spacer(vbox, 10)

	# Opponent info
	_opponent_label = Label.new()
	_opponent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_opponent_label.add_theme_font_size_override("font_size", 18)
	_opponent_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.6))
	vbox.add_child(_opponent_label)

	_opponent_desc_label = Label.new()
	_opponent_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_opponent_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_opponent_desc_label.add_theme_color_override("font_color", Color(0.55, 0.5, 0.4))
	vbox.add_child(_opponent_desc_label)

	_add_spacer(vbox, 10)

	# Progress
	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
	vbox.add_child(_progress_label)

	# Reputation
	_reputation_label = Label.new()
	_reputation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reputation_label.add_theme_font_size_override("font_size", 16)
	_reputation_label.add_theme_color_override("font_color", Color(0.8, 0.72, 0.45))
	vbox.add_child(_reputation_label)

	# Match history
	_history_label = Label.new()
	_history_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_history_label.add_theme_font_size_override("font_size", 13)
	_history_label.add_theme_color_override("font_color", Color(0.5, 0.47, 0.38))
	_history_label.visible = false
	vbox.add_child(_history_label)

	_add_spacer(vbox, 15)

	# Challenge button
	_challenge_button = Button.new()
	_challenge_button.text = "Challenge"
	_challenge_button.pressed.connect(_on_challenge_pressed)
	_challenge_button.custom_minimum_size = Vector2(200, 50)
	vbox.add_child(_challenge_button)

	# Status text (for messages like "Chapter complete" etc.)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	_status_label.visible = false
	vbox.add_child(_status_label)

	# Reputation breakdown panel (hidden until needed)
	_rep_panel = PanelContainer.new()
	_rep_panel.set_anchors_preset(PRESET_CENTER)
	_rep_panel.offset_left = -140.0
	_rep_panel.offset_right = 140.0
	_rep_panel.offset_top = -80.0
	_rep_panel.offset_bottom = 80.0
	_rep_panel.visible = false
	add_child(_rep_panel)

	var rep_vbox := VBoxContainer.new()
	rep_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_rep_panel.add_child(rep_vbox)

	_rep_breakdown_label = Label.new()
	_rep_breakdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rep_breakdown_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.65))
	rep_vbox.add_child(_rep_breakdown_label)

	_rep_continue_button = Button.new()
	_rep_continue_button.text = "Continue"
	_rep_continue_button.pressed.connect(_on_rep_continue)
	rep_vbox.add_child(_rep_continue_button)


func _add_spacer(parent: VBoxContainer, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)


# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------

func _update_display() -> void:
	if _campaign == null:
		return

	var chapter_info: Dictionary = _campaign.get_current_chapter_info()
	_chapter_label.text = chapter_info.get("name", "Chapter ???")
	_location_label.text = chapter_info.get("location", "")

	var opponent: Resource = _campaign.get_current_opponent()
	if opponent != null:
		_opponent_label.text = opponent.character_name
		_opponent_desc_label.text = opponent.description
	else:
		_opponent_label.text = ""
		_opponent_desc_label.text = ""

	var match_num: int = _campaign.current_match_in_chapter + 1
	var total: int = _campaign.get_chapter_match_count()
	_progress_label.text = "Match %d of %d" % [match_num, total]

	var rep: int = 0
	if _reputation != null:
		rep = _reputation.get_reputation()
	_reputation_label.text = "Reputation: %d" % rep

	# Match history summary
	_update_history_display()

	# Check if chapter is complete
	if _campaign.is_chapter_complete():
		if _campaign.can_advance_chapter():
			_challenge_button.text = "Continue Journey"
			_challenge_button.visible = true
			_status_label.text = "Chapter complete"
			_status_label.visible = true
			_progress_label.text = "All matches won"
		else:
			_challenge_button.visible = false
			var next_info: Dictionary = _campaign._get_chapter_info(_campaign.current_chapter + 1)
			var threshold: int = int(next_info.get("rep_threshold", 0))
			_status_label.text = "Need %d reputation to continue (have %d)" % [threshold, rep]
			_status_label.visible = true
	elif _campaign.state == _campaign.CampaignState.CAMPAIGN_COMPLETE:
		_challenge_button.visible = false
		_status_label.text = "Campaign Complete"
		_status_label.visible = true
	else:
		_challenge_button.text = "Challenge"
		_challenge_button.visible = true
		_status_label.visible = false


func _update_history_display() -> void:
	if _campaign == null:
		_history_label.visible = false
		return

	var history: Dictionary = _campaign.match_history
	if history.is_empty():
		_history_label.visible = false
		return

	var total_wins: int = 0
	var total_losses: int = 0
	for opponent_id: String in history:
		var records: Array = history[opponent_id]
		for record: Dictionary in records:
			if record.get("result", "") == "win":
				total_wins += 1
			elif record.get("result", "") == "loss":
				total_losses += 1

	_history_label.text = "Record: %dW – %dL" % [total_wins, total_losses]
	_history_label.visible = true


# ---------------------------------------------------------------------------
# Match Flow
# ---------------------------------------------------------------------------

func _on_challenge_pressed() -> void:
	if _campaign == null:
		return

	# If chapter complete, advance
	if _campaign.is_chapter_complete() and _campaign.can_advance_chapter():
		_campaign.advance_chapter()
		_update_display()
		# Show chapter transition narrator
		if _campaign.current_chapter == 1:
			_show_narrator("narrator_ch1_start")
		return

	# Mark opponent as encountered
	var opponent: Resource = _campaign.get_current_opponent()
	if opponent != null:
		_campaign.encountered_opponents[opponent.character_id] = true

	# Show pre-match dialogue, then launch match
	_start_pre_dialogue()


func _start_pre_dialogue() -> void:
	if _dialogue == null:
		_launch_match()
		return

	var context: Dictionary = _campaign.build_dialogue_context("pre_match")
	var lines: Array = _dialogue.show_dialogue(context)

	if lines.is_empty():
		_launch_match()
		return

	# Show dialogue overlay
	var overlay: Control = _create_dialogue_overlay()
	add_child(overlay)
	overlay.completed.connect(_on_pre_dialogue_complete)


func _on_pre_dialogue_complete() -> void:
	_launch_match()


func _launch_match() -> void:
	if _scene_manager == null:
		return

	var opponent: Resource = _campaign.get_current_opponent()
	var entry: Dictionary = _campaign.get_current_match_entry()

	_scene_manager.scene_data = {
		"opponent_profile_path": entry.get("opponent_path", ""),
		"campaign_mode": true,
		"match_type": entry.get("match_type", "standard"),
	}

	# Hide and transition
	visible = false
	_scene_manager.change_scene(&"match")
	queue_free()


## Called when returning from a match with a result.
func _handle_match_return() -> void:
	var winner: int = _match_result.get("winner", -1)
	var player_won: bool = (winner == 1)  # Side.DEFENDER

	# Build dialogue context BEFORE processing result, so encounter count
	# and result_history reflect the state the player experienced the match in.
	var timing: String = "post_win" if player_won else "post_loss"
	var pre_process_context: Dictionary = _campaign.build_dialogue_context(timing)

	# Now process the result (updates match history, awards reputation, advances)
	_campaign.process_match_result(_match_result)

	# Show post-match dialogue using pre-process context
	if _dialogue != null:
		var lines: Array = _dialogue.show_dialogue(pre_process_context)
		if not lines.is_empty():
			var overlay: Control = _create_dialogue_overlay()
			add_child(overlay)
			if player_won:
				overlay.completed.connect(_show_reputation_breakdown)
			else:
				overlay.completed.connect(_on_post_dialogue_complete)
			return

	# No dialogue — skip to reputation or update
	if player_won:
		_show_reputation_breakdown()
	else:
		_on_post_dialogue_complete()


func _show_reputation_breakdown() -> void:
	if _reputation == null:
		_on_post_dialogue_complete()
		return

	var award: Dictionary = _reputation.get_last_award()
	if award.is_empty():
		_on_post_dialogue_complete()
		return

	var breakdown: Dictionary = award.get("breakdown", {})
	var text: String = "Reputation earned:\n"
	for key: String in breakdown:
		text += "  %s: +%d\n" % [key.capitalize(), breakdown[key]]
	text += "\nTotal: +%d (now %d)" % [award.get("earned", 0), award.get("total_after", 0)]

	_rep_breakdown_label.text = text
	_rep_panel.visible = true

	# Auto-play: dismiss rep panel after delay
	if _autoplay:
		await get_tree().create_timer(2.0).timeout
		_on_rep_continue()


func _on_rep_continue() -> void:
	_rep_panel.visible = false
	_on_post_dialogue_complete()


func _on_post_dialogue_complete() -> void:
	# Check if chapter just completed
	if _campaign.is_chapter_complete() and _campaign.current_chapter == 0:
		# Prologue complete — show narrator, then advance to Chapter 1
		if _campaign.can_advance_chapter():
			_show_narrator_then_advance("narrator_ch0_post_scripted")
			return

	_update_display()

	# Auto-play: continue to next challenge
	if _autoplay:
		_autoplay_challenge()


## Show a narrator line, then advance chapter and update display.
func _show_narrator_then_advance(line_id: String) -> void:
	if _dialogue == null:
		_campaign.advance_chapter()
		_update_display()
		return

	var context: Dictionary = { "opponent_id": "narrator" }
	var lines: Array = _dialogue.select_lines(context)

	for line: Dictionary in lines:
		if line.get("id", "") == line_id:
			_dialogue._current_lines = [line]
			_dialogue._current_line_index = 0
			_dialogue._active = true

			var overlay: Control = _create_dialogue_overlay()
			add_child(overlay)
			overlay.completed.connect(func() -> void:
				_campaign.advance_chapter()
				_update_display()
				if _autoplay:
					_autoplay_challenge())
			return

	# Line not found — just advance
	_campaign.advance_chapter()
	_update_display()
	if _autoplay:
		_autoplay_challenge()


func _show_narrator(line_id: String) -> void:
	if _dialogue == null:
		return

	# Find the narrator line by ID and show it
	var context: Dictionary = { "opponent_id": "narrator" }
	var lines: Array = _dialogue.select_lines(context)

	# Find the specific line
	for line: Dictionary in lines:
		if line.get("id", "") == line_id:
			_dialogue._current_lines = [line]
			_dialogue._current_line_index = 0
			_dialogue._active = true

			var overlay: Control = _create_dialogue_overlay()
			add_child(overlay)
			if _autoplay:
				overlay.completed.connect(_autoplay_challenge)
			return


func _create_dialogue_overlay() -> Control:
	var DialogueOverlayScript: GDScript = preload("res://src/ui/dialogue_overlay.gd")
	var overlay: Control = DialogueOverlayScript.new()
	if _autoplay:
		overlay.set_meta("autoplay", true)
	return overlay


## Debug: auto-press challenge after a brief delay.
func _autoplay_challenge() -> void:
	if _campaign == null:
		return
	# Stop if campaign is complete or no more matches
	if _campaign.state == _campaign.CampaignState.CAMPAIGN_COMPLETE:
		print("[AUTOPLAY] Campaign complete — stopping")
		return
	print("[AUTOPLAY] Auto-challenge in 2s...")
	await get_tree().create_timer(2.0).timeout
	if _challenge_button.visible:
		print("[AUTOPLAY] Pressing Challenge")
		_on_challenge_pressed()
	else:
		print("[AUTOPLAY] No challenge available — campaign may be gated")
