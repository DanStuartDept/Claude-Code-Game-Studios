## Campaign Map — Displays current chapter opponents as cards with match flow.
##
## The hub screen between matches. Shows all opponents in the current chapter
## as a scrollable card list with visual states: Upcoming, Active, Won,
## Lost-then-Won, Feud, Nemesis, Feud Resolved. Handles the full match flow:
## campaign map → pre-dialogue → match → post-dialogue → reputation → campaign map.
##
## Architecture: Presentation Layer (ADR-0001).
## See: design/gdd/campaign-ui.md, design/gdd/campaign-system.md
extends Control


# --- Card States ---

enum CardState {
	UPCOMING,
	ACTIVE,
	WON,
	LOST_THEN_WON,
	FEUD,
	NEMESIS,
	FEUD_RESOLVED,
}

# --- Card State Colors ---

const COLOR_BG := Color(0.10, 0.08, 0.05)
const COLOR_GOLD := Color(0.9, 0.82, 0.55)
const COLOR_MUTED := Color(0.6, 0.55, 0.45)
const COLOR_DIM := Color(0.35, 0.32, 0.28)
const COLOR_TEXT := Color(0.85, 0.78, 0.6)
const COLOR_DESC := Color(0.55, 0.5, 0.4)
const COLOR_WIN := Color(0.4, 0.7, 0.35)
const COLOR_FEUD := Color(0.8, 0.35, 0.25)
const COLOR_NEMESIS := Color(0.7, 0.2, 0.2)
const COLOR_RESOLVED := Color(0.45, 0.6, 0.5)
const COLOR_ACTIVE_GLOW := Color(0.9, 0.82, 0.55, 0.15)

# --- Card Dimensions ---

const CARD_MIN_HEIGHT: float = 80.0
const CARD_TAP_MIN: float = 44.0


# --- UI References ---

var _header_chapter_label: Label = null
var _header_location_label: Label = null
var _header_rep_label: Label = null
var _header_rep_bar: ProgressBar = null
var _header_rep_tier: Label = null
var _card_container: VBoxContainer = null
var _scroll: ScrollContainer = null
var _status_label: Label = null
var _chapter_dots: HBoxContainer = null

# --- Reputation Breakdown Panel ---
var _rep_panel: PanelContainer = null
var _rep_breakdown_label: Label = null
var _rep_continue_button: Button = null

# --- State ---

var _campaign: Node = null
var _dialogue: Node = null
var _reputation: Node = null
var _feud: Node = null
var _scene_manager: Node = null
var _match_result: Dictionary = {}
var _autoplay: bool = false
var _card_buttons: Array = []
var _animate_rep_bar: bool = false


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_campaign = get_node_or_null("/root/CampaignSystem")
	_dialogue = get_node_or_null("/root/DialogueSystem")
	_reputation = get_node_or_null("/root/ReputationSystem")
	_feud = get_node_or_null("/root/FeudSystem")
	_scene_manager = get_node_or_null("/root/SceneManager")
	_autoplay = OS.get_cmdline_args().has("--autoplay") or OS.get_cmdline_user_args().has("--autoplay")

	# Register scenes
	if _scene_manager != null:
		_scene_manager.register_scene(&"match", "res://scenes/match/Match.tscn")
		_scene_manager.register_scene(&"campaign_map", "res://scenes/campaign/CampaignMap.tscn")
		_scene_manager.register_scene(&"menu", "res://scenes/menu/MainMenu.tscn")

	_build_ui()

	# Start chapter-appropriate ambient and campaign music
	var audio: Node = get_node_or_null("/root/AudioSystem")
	if audio != null and _campaign != null:
		var chapter_idx: int = _campaign.current_chapter
		audio.play_ambient_for_chapter(chapter_idx)
		audio.play_music("campaign_chapter_%d" % chapter_idx)

	# Start new campaign if not active
	if _campaign != null and not _campaign.campaign_active:
		_campaign.start_new_campaign()

	_refresh_cards()

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
	bg.color = COLOR_BG
	add_child(bg)

	# --- Fixed Header ---
	var header := VBoxContainer.new()
	header.set_anchors_preset(PRESET_TOP_WIDE)
	header.offset_left = 16.0
	header.offset_right = -16.0
	header.offset_top = 10.0
	header.offset_bottom = 155.0
	header.add_theme_constant_override("separation", 4)
	add_child(header)

	# Chapter name
	_header_chapter_label = Label.new()
	_header_chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_chapter_label.add_theme_font_size_override("font_size", 22)
	_header_chapter_label.add_theme_color_override("font_color", COLOR_GOLD)
	header.add_child(_header_chapter_label)

	# Location
	_header_location_label = Label.new()
	_header_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_location_label.add_theme_font_size_override("font_size", 14)
	_header_location_label.add_theme_color_override("font_color", COLOR_MUTED)
	header.add_child(_header_location_label)

	# Reputation bar row
	var rep_row := HBoxContainer.new()
	rep_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rep_row.add_theme_constant_override("separation", 8)
	header.add_child(rep_row)

	_header_rep_tier = Label.new()
	_header_rep_tier.add_theme_font_size_override("font_size", 13)
	_header_rep_tier.add_theme_color_override("font_color", COLOR_GOLD)
	rep_row.add_child(_header_rep_tier)

	_header_rep_bar = ProgressBar.new()
	_header_rep_bar.custom_minimum_size = Vector2(160, 16)
	_header_rep_bar.show_percentage = false
	rep_row.add_child(_header_rep_bar)

	_header_rep_label = Label.new()
	_header_rep_label.add_theme_font_size_override("font_size", 13)
	_header_rep_label.add_theme_color_override("font_color", COLOR_MUTED)
	rep_row.add_child(_header_rep_label)

	# Status label (chapter complete, reputation gate, etc.)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", COLOR_MUTED)
	_status_label.visible = false
	header.add_child(_status_label)

	# Chapter navigation dots
	_chapter_dots = HBoxContainer.new()
	_chapter_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_chapter_dots.add_theme_constant_override("separation", 12)
	header.add_child(_chapter_dots)

	# --- Scrollable Card List ---
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(PRESET_FULL_RECT)
	_scroll.offset_top = 160.0
	_scroll.offset_bottom = -10.0
	_scroll.offset_left = 12.0
	_scroll.offset_right = -12.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_card_container = VBoxContainer.new()
	_card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_container.add_theme_constant_override("separation", 10)
	_scroll.add_child(_card_container)

	# --- Settings Button (top-right) ---
	var settings_button := Button.new()
	settings_button.text = "Settings"
	settings_button.set_anchors_preset(PRESET_TOP_RIGHT)
	settings_button.offset_left = -100.0
	settings_button.offset_right = -10.0
	settings_button.offset_top = 10.0
	settings_button.offset_bottom = 10.0 + CARD_TAP_MIN
	settings_button.pressed.connect(_on_settings_pressed)
	add_child(settings_button)

	# --- Reputation Breakdown Panel (hidden) ---
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


# ---------------------------------------------------------------------------
# Card Display
# ---------------------------------------------------------------------------

func _refresh_cards() -> void:
	_update_header()
	_rebuild_card_list()


func _update_header() -> void:
	if _campaign == null:
		return

	var chapter_info: Dictionary = _campaign.get_current_chapter_info()
	_header_chapter_label.text = chapter_info.get("name", "Chapter ???")
	_header_location_label.text = chapter_info.get("location", "")

	# Reputation bar
	var rep: int = 0
	var tier: String = "Unknown"
	var next_threshold: int = 0
	var prev_threshold: int = 0

	if _reputation != null:
		rep = _reputation.get_reputation()
		tier = _reputation.get_reputation_tier().capitalize()
		if _reputation.has_method("get_next_threshold"):
			var threshold_data: Dictionary = _reputation.get_next_threshold()
			next_threshold = int(threshold_data.get("threshold", 0))
		# Calculate previous threshold for bar range
		var thresholds: Array = [0, 5, 15, 35, 60]
		for t: int in thresholds:
			if t < next_threshold or next_threshold == 0:
				prev_threshold = t

	_header_rep_tier.text = tier
	if next_threshold > 0:
		_header_rep_bar.min_value = prev_threshold
		_header_rep_bar.max_value = next_threshold
		if _animate_rep_bar and _header_rep_bar.value != rep:
			var tween: Tween = create_tween()
			tween.tween_property(_header_rep_bar, "value", float(rep), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			_animate_rep_bar = false
		else:
			_header_rep_bar.value = rep
		_header_rep_label.text = "%d / %d" % [rep, next_threshold]
	else:
		_header_rep_bar.min_value = 0
		_header_rep_bar.max_value = 1
		_header_rep_bar.value = 1
		_header_rep_label.text = "%d" % rep

	# Status messages
	_status_label.visible = false
	if _campaign.state == _campaign.CampaignState.CAMPAIGN_COMPLETE:
		_status_label.text = "Journey Complete"
		_status_label.visible = true
	elif _campaign.is_chapter_complete():
		if _campaign.can_advance_chapter():
			_status_label.text = "Chapter complete — tap Continue Journey"
			_status_label.visible = true
		else:
			var next_info: Dictionary = _campaign._get_chapter_info(_campaign.current_chapter + 1)
			var threshold: int = int(next_info.get("rep_threshold", 0))
			_status_label.text = "Need %d reputation to continue (have %d)" % [threshold, rep]
			_status_label.visible = true

	# Chapter dots
	_update_chapter_dots(rep)


func _update_chapter_dots(current_rep: int) -> void:
	for child: Node in _chapter_dots.get_children():
		child.queue_free()

	if _campaign == null:
		return

	var total_chapters: int = _campaign._get_chapter_count()
	for i: int in total_chapters:
		var ch_info: Dictionary = _campaign._get_chapter_info(i)
		var threshold: int = int(ch_info.get("rep_threshold", 0))
		var is_current: bool = (i == _campaign.current_chapter)
		var is_completed: bool = (i < _campaign.current_chapter)
		var is_locked: bool = (i > _campaign.current_chapter) and current_rep < threshold

		var dot := Button.new()
		dot.flat = true
		dot.custom_minimum_size = Vector2(20, 20)
		dot.tooltip_text = ch_info.get("name", "Ch %d" % i)

		var style := StyleBoxFlat.new()
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10

		if is_current:
			style.bg_color = COLOR_GOLD
		elif is_completed:
			style.bg_color = COLOR_WIN
			var ch_index: int = i
			dot.pressed.connect(_on_chapter_dot_pressed.bind(ch_index))
		elif is_locked:
			style.bg_color = COLOR_DIM
		else:
			style.bg_color = COLOR_MUTED

		dot.add_theme_stylebox_override("normal", style)
		dot.add_theme_stylebox_override("hover", style)
		dot.add_theme_stylebox_override("pressed", style)
		dot.add_theme_stylebox_override("focus", style)

		_chapter_dots.add_child(dot)


func _on_chapter_dot_pressed(chapter_index: int) -> void:
	if _campaign == null:
		return
	if chapter_index >= _campaign.current_chapter:
		return

	var ch_info: Dictionary = _campaign._get_chapter_info(chapter_index)
	_header_chapter_label.text = ch_info.get("name", "Chapter ???")
	_header_location_label.text = ch_info.get("location", "")

	for child: Node in _card_container.get_children():
		child.queue_free()
	_card_buttons.clear()

	var chapter_matches: Array = _campaign._get_chapter_matches(chapter_index)
	for i: int in chapter_matches.size():
		var entry: Dictionary = chapter_matches[i]
		var card: PanelContainer = _create_opponent_card(entry, CardState.WON, i)
		_card_container.add_child(card)

	var back_btn := Button.new()
	back_btn.text = "Back to Current Chapter"
	back_btn.custom_minimum_size = Vector2(0, CARD_TAP_MIN)
	back_btn.pressed.connect(_refresh_cards)
	_card_container.add_child(back_btn)


func _rebuild_card_list() -> void:
	# Clear existing cards
	for child: Node in _card_container.get_children():
		child.queue_free()
	_card_buttons.clear()

	if _campaign == null:
		return

	# Check for chapter complete with advance available
	if _campaign.is_chapter_complete() and _campaign.can_advance_chapter():
		var advance_btn := _create_advance_button()
		_card_container.add_child(advance_btn)

	# Build cards for all matches in current chapter
	var chapter_matches: Array = _campaign._get_chapter_matches(_campaign.current_chapter)
	for i: int in chapter_matches.size():
		var entry: Dictionary = chapter_matches[i]
		var card_state: CardState = _determine_card_state(entry, i)
		var card: PanelContainer = _create_opponent_card(entry, card_state, i)
		_card_container.add_child(card)
		_card_buttons.append(card)


func _determine_card_state(entry: Dictionary, index: int) -> CardState:
	var match_id: String = entry.get("match_id", "")
	var opponent_path: String = entry.get("opponent_path", "")
	var is_completed: bool = _campaign.completed_matches.has(match_id)
	var is_active: bool = (index == _campaign.current_match_in_chapter) and not _campaign.is_chapter_complete()

	# Load opponent for feud check
	var opponent_id: String = ""
	if opponent_path != "" and ResourceLoader.exists(opponent_path):
		var profile: Resource = load(opponent_path)
		if profile != null:
			opponent_id = profile.character_id

	# Check feud state
	var feud_state: String = "neutral"
	if _feud != null and opponent_id != "":
		feud_state = _feud.get_feud_state(opponent_id)

	if is_completed:
		# Check if player lost before winning (lost-then-won)
		if feud_state == "feud_resolved":
			return CardState.FEUD_RESOLVED
		if opponent_id != "" and _campaign.has_lost_to(opponent_id):
			return CardState.LOST_THEN_WON
		return CardState.WON
	elif is_active:
		if feud_state == "in_feud":
			return CardState.FEUD
		elif feud_state == "nemesis":
			return CardState.NEMESIS
		return CardState.ACTIVE
	else:
		return CardState.UPCOMING


func _create_opponent_card(entry: Dictionary, state: CardState, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, CARD_MIN_HEIGHT)

	# Card background style
	var style := StyleBoxFlat.new()
	style.bg_color = _get_card_bg_color(state)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0

	# Active glow border
	if state == CardState.ACTIVE:
		style.border_color = COLOR_GOLD
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
	elif state == CardState.FEUD:
		style.border_color = COLOR_FEUD
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
	elif state == CardState.NEMESIS:
		style.border_color = COLOR_NEMESIS
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2

	panel.add_theme_stylebox_override("panel", style)

	# Card content
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Portrait placeholder (colored square)
	var portrait := ColorRect.new()
	portrait.custom_minimum_size = Vector2(50, 50)
	portrait.color = _get_portrait_color(state)
	hbox.add_child(portrait)

	# Text column
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	hbox.add_child(text_col)

	# Load opponent profile
	var opponent_path: String = entry.get("opponent_path", "")
	var profile: Resource = null
	if opponent_path != "" and ResourceLoader.exists(opponent_path):
		profile = load(opponent_path)

	# Name row (name + status indicator)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	text_col.add_child(name_row)

	var name_label := Label.new()
	name_label.text = profile.character_name if profile != null else "???"
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", _get_name_color(state))
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_label)

	# Status indicator
	var indicator := Label.new()
	indicator.add_theme_font_size_override("font_size", 14)
	indicator.text = _get_status_indicator(state)
	indicator.add_theme_color_override("font_color", _get_indicator_color(state))
	name_row.add_child(indicator)

	# Description
	var desc_label := Label.new()
	desc_label.text = profile.description if profile != null else ""
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", COLOR_DESC if state != CardState.UPCOMING else COLOR_DIM)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.clip_text = true
	text_col.add_child(desc_label)

	# Boss indicator
	if entry.get("is_chapter_boss", false):
		var boss_label := Label.new()
		boss_label.text = "Chapter Boss"
		boss_label.add_theme_font_size_override("font_size", 11)
		boss_label.add_theme_color_override("font_color", COLOR_GOLD if state != CardState.UPCOMING else COLOR_DIM)
		text_col.add_child(boss_label)

	# Match summary for completed cards
	if state == CardState.WON or state == CardState.LOST_THEN_WON or state == CardState.FEUD_RESOLVED:
		var opponent_id: String = profile.character_id if profile != null else ""
		if opponent_id != "" and _campaign.match_history.has(opponent_id):
			var records: Array = _campaign.match_history[opponent_id]
			var wins: int = 0
			var losses: int = 0
			for rec: Dictionary in records:
				if rec.get("result", "") == "win":
					wins += 1
				elif rec.get("result", "") == "loss":
					losses += 1
			var summary_label := Label.new()
			summary_label.add_theme_font_size_override("font_size", 11)
			summary_label.add_theme_color_override("font_color", COLOR_MUTED)
			if losses > 0:
				summary_label.text = "Record: %dW – %dL" % [wins, losses]
			else:
				summary_label.text = "Won on first attempt"
			text_col.add_child(summary_label)

	# Make active/feud/nemesis cards tappable (starts match)
	if state == CardState.ACTIVE or state == CardState.FEUD or state == CardState.NEMESIS:
		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(PRESET_FULL_RECT)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(_on_card_pressed.bind(index))
		panel.add_child(btn)

	return panel


func _create_advance_button() -> Button:
	var btn := Button.new()
	btn.text = "Continue Journey"
	btn.custom_minimum_size = Vector2(0, CARD_TAP_MIN)
	btn.pressed.connect(_on_advance_pressed)
	return btn


func _get_card_bg_color(state: CardState) -> Color:
	match state:
		CardState.UPCOMING:
			return Color(0.12, 0.10, 0.08)
		CardState.ACTIVE:
			return Color(0.16, 0.14, 0.10)
		CardState.WON:
			return Color(0.12, 0.15, 0.10)
		CardState.LOST_THEN_WON:
			return Color(0.14, 0.15, 0.10)
		CardState.FEUD:
			return Color(0.18, 0.12, 0.10)
		CardState.NEMESIS:
			return Color(0.20, 0.10, 0.10)
		CardState.FEUD_RESOLVED:
			return Color(0.12, 0.14, 0.12)
	return Color(0.12, 0.10, 0.08)


func _get_portrait_color(state: CardState) -> Color:
	match state:
		CardState.UPCOMING:
			return Color(0.2, 0.18, 0.15)
		CardState.ACTIVE:
			return Color(0.5, 0.45, 0.3)
		CardState.WON, CardState.LOST_THEN_WON:
			return Color(0.3, 0.45, 0.3)
		CardState.FEUD:
			return Color(0.5, 0.25, 0.15)
		CardState.NEMESIS:
			return Color(0.5, 0.15, 0.15)
		CardState.FEUD_RESOLVED:
			return Color(0.3, 0.4, 0.35)
	return Color(0.3, 0.25, 0.2)


func _get_name_color(state: CardState) -> Color:
	match state:
		CardState.UPCOMING:
			return COLOR_DIM
		CardState.ACTIVE:
			return COLOR_GOLD
		CardState.FEUD:
			return COLOR_FEUD
		CardState.NEMESIS:
			return COLOR_NEMESIS
	return COLOR_TEXT


func _get_status_indicator(state: CardState) -> String:
	match state:
		CardState.WON:
			return "Won"
		CardState.LOST_THEN_WON:
			return "Won (Hard-Fought)"
		CardState.FEUD:
			return "Feud"
		CardState.NEMESIS:
			return "Nemesis"
		CardState.FEUD_RESOLVED:
			return "Resolved"
		CardState.ACTIVE:
			return ">"
	return ""


func _get_indicator_color(state: CardState) -> Color:
	match state:
		CardState.WON, CardState.LOST_THEN_WON:
			return COLOR_WIN
		CardState.FEUD:
			return COLOR_FEUD
		CardState.NEMESIS:
			return COLOR_NEMESIS
		CardState.FEUD_RESOLVED:
			return COLOR_RESOLVED
		CardState.ACTIVE:
			return COLOR_GOLD
	return COLOR_DIM


# ---------------------------------------------------------------------------
# Card Interaction
# ---------------------------------------------------------------------------

func _on_card_pressed(match_index: int) -> void:
	if _campaign == null:
		return

	# Only allow pressing the current active match
	if match_index != _campaign.current_match_in_chapter:
		return

	# Mark opponent as encountered
	var opponent: Resource = _campaign.get_current_opponent()
	if opponent != null:
		_campaign.encountered_opponents[opponent.character_id] = true

	_start_pre_dialogue()


func _on_advance_pressed() -> void:
	if _campaign == null:
		return

	if _campaign.is_chapter_complete() and _campaign.can_advance_chapter():
		var old_ch: int = _campaign.current_chapter
		_campaign.advance_chapter()
		_refresh_cards()
		var start_id: String = "narrator_ch%d_start" % _campaign.current_chapter
		_show_narrator(start_id)


# ---------------------------------------------------------------------------
# Match Flow
# ---------------------------------------------------------------------------

func _start_pre_dialogue() -> void:
	if _dialogue == null:
		_launch_match()
		return

	var context: Dictionary = _campaign.build_dialogue_context("pre_match")
	var lines: Array = _dialogue.show_dialogue(context)

	if lines.is_empty():
		_launch_match()
		return

	var overlay: Control = _create_dialogue_overlay()
	add_child(overlay)
	overlay.completed.connect(_on_pre_dialogue_complete)


func _on_pre_dialogue_complete() -> void:
	_launch_match()


func _launch_match() -> void:
	if _scene_manager == null:
		return

	var entry: Dictionary = _campaign.get_current_match_entry()

	_scene_manager.scene_data = {
		"opponent_profile_path": entry.get("opponent_path", ""),
		"campaign_mode": true,
		"match_type": entry.get("match_type", "standard"),
	}

	visible = false
	_scene_manager.change_scene(&"match")
	queue_free()


func _handle_match_return() -> void:
	var winner: int = _match_result.get("winner", -1)
	var player_won: bool = (winner == 1)  # Side.DEFENDER

	var timing: String = "post_win" if player_won else "post_loss"
	var pre_process_context: Dictionary = _campaign.build_dialogue_context(timing)

	_campaign.process_match_result(_match_result)

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

	if _autoplay:
		await get_tree().create_timer(2.0).timeout
		_on_rep_continue()


func _on_rep_continue() -> void:
	_rep_panel.visible = false
	_animate_rep_bar = true
	_on_post_dialogue_complete()


func _on_post_dialogue_complete() -> void:
	if _campaign.is_chapter_complete():
		var end_id: String = "narrator_ch%d_end" % _campaign.current_chapter
		if _campaign.current_chapter == 0:
			end_id = "narrator_ch0_post_scripted"
		if _campaign.can_advance_chapter():
			_show_narrator_then_advance(end_id)
			return

	_refresh_cards()

	if _autoplay:
		_autoplay_challenge()


func _show_narrator_then_advance(line_id: String) -> void:
	if _dialogue == null:
		_campaign.advance_chapter()
		_refresh_cards()
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
				_refresh_cards()
				if _autoplay:
					_autoplay_challenge())
			return

	_campaign.advance_chapter()
	_refresh_cards()
	if _autoplay:
		_autoplay_challenge()


func _show_narrator(line_id: String) -> void:
	if _dialogue == null:
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
			if _autoplay:
				overlay.completed.connect(_autoplay_challenge)
			return


func _create_dialogue_overlay() -> Control:
	var DialogueOverlayScript: GDScript = preload("res://src/ui/dialogue_overlay.gd")
	var overlay: Control = DialogueOverlayScript.new()
	if _autoplay:
		overlay.set_meta("autoplay", true)
	return overlay


# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------

func _on_settings_pressed() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_CENTER)
	panel.offset_left = -160.0
	panel.offset_right = 160.0
	panel.offset_top = -200.0
	panel.offset_bottom = 200.0
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	vbox.add_child(title)

	# Volume sliders
	var audio: Node = get_node_or_null("/root/AudioSystem")
	_add_volume_slider(vbox, "Master", "master", audio)
	_add_volume_slider(vbox, "Music", "music", audio)
	_add_volume_slider(vbox, "SFX", "sfx", audio)
	_add_volume_slider(vbox, "Ambient", "ambient", audio)

	var text_speed_btn := Button.new()
	text_speed_btn.text = "Text Speed: Instant"
	text_speed_btn.pressed.connect(func() -> void:
		if text_speed_btn.text == "Text Speed: Instant":
			text_speed_btn.text = "Text Speed: Typewriter"
		else:
			text_speed_btn.text = "Text Speed: Instant")
	vbox.add_child(text_speed_btn)

	var new_game_btn := Button.new()
	new_game_btn.text = "New Game"
	new_game_btn.pressed.connect(func() -> void:
		panel.queue_free()
		_confirm_new_game())
	vbox.add_child(new_game_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func() -> void:
		panel.queue_free()
		# Persist audio settings on close
		var save: Node = get_node_or_null("/root/SaveSystem")
		if save != null:
			save.save_game()
	)
	vbox.add_child(close_btn)


func _add_volume_slider(parent: VBoxContainer, label_text: String, bus_name: String, audio: Node) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(60, 0)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(120, 20)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if bus_name == "master":
		var master_idx: int = AudioServer.get_bus_index(&"Master")
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_idx)) if master_idx >= 0 else 1.0
	elif audio != null:
		slider.value = audio.get_bus_volume(bus_name)
	else:
		slider.value = 1.0

	slider.value_changed.connect(func(val: float) -> void:
		if bus_name == "master":
			var idx: int = AudioServer.get_bus_index(&"Master")
			if idx >= 0:
				AudioServer.set_bus_volume_db(idx, linear_to_db(val))
		elif audio != null:
			audio.set_bus_volume(bus_name, val)
	)
	hbox.add_child(slider)


func _confirm_new_game() -> void:
	var save: Node = get_node_or_null("/root/SaveSystem")
	if save != null and save.has_save():
		var dialog := ConfirmationDialog.new()
		dialog.dialog_text = "Starting a new game will erase your current journey. Are you sure?"
		dialog.ok_button_text = "New Game"
		dialog.cancel_button_text = "Cancel"
		dialog.confirmed.connect(func() -> void:
			dialog.queue_free()
			if save != null:
				save.delete_save()
			_return_to_menu())
		dialog.canceled.connect(func() -> void: dialog.queue_free())
		add_child(dialog)
		dialog.popup_centered()
	else:
		_return_to_menu()


func _return_to_menu() -> void:
	if _scene_manager != null:
		visible = false
		_scene_manager.change_scene(&"menu")
		queue_free()


## Debug: auto-press challenge after a brief delay.
func _autoplay_challenge() -> void:
	if _campaign == null:
		return
	if _campaign.state == _campaign.CampaignState.CAMPAIGN_COMPLETE:
		print("[AUTOPLAY] Campaign complete — stopping")
		return
	print("[AUTOPLAY] Auto-challenge in 2s...")
	await get_tree().create_timer(2.0).timeout
	if _campaign.is_chapter_complete() and _campaign.can_advance_chapter():
		print("[AUTOPLAY] Advancing chapter")
		_on_advance_pressed()
	elif not _campaign.is_chapter_complete():
		print("[AUTOPLAY] Pressing active card")
		_on_card_pressed(_campaign.current_match_in_chapter)
	else:
		print("[AUTOPLAY] No action available — campaign may be gated")
