## Dialogue Overlay — Displays character dialogue with tap-to-advance.
##
## Shows character name, text, and a "tap to continue" prompt.
## Pushed as a SceneManager overlay during pre/post-match dialogue.
## Tap advances to next line; after last line, overlay pops itself.
## Narrator lines use distinct styling: centered, italic, muted tones.
##
## Architecture: Presentation Layer (ADR-0001).
## See: design/gdd/dialogue-system.md
class_name DialogueOverlay
extends Control


# --- Signals ---

## Emitted when all dialogue lines have been shown and dismissed.
signal completed()


# --- UI References ---

var _bg: ColorRect = null
var _panel: PanelContainer = null
var _name_label: Label = null
var _text_label: Label = null
var _continue_label: Label = null

## Narrator-specific styling colors.
const NARRATOR_TEXT_COLOR: Color = Color(0.75, 0.72, 0.65)
const NARRATOR_BG_COLOR: Color = Color(0.0, 0.0, 0.0, 0.65)
const CHARACTER_TEXT_COLOR: Color = Color(0.85, 0.82, 0.75)
const CHARACTER_BG_COLOR: Color = Color(0.0, 0.0, 0.0, 0.5)


# --- State ---

## The DialogueSystem node (autoload).
var _dialogue_system: Node = null

## Minimum delay between taps to prevent accidental skips.
var _tap_cooldown: float = 0.2
var _last_tap_time: float = 0.0


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_dialogue_system = get_node_or_null("/root/DialogueSystem")
	_build_ui()

	if _dialogue_system != null and _dialogue_system.is_active():
		_show_current_line()

	# Auto-play: advance dialogue automatically
	if has_meta("autoplay") and get_meta("autoplay"):
		_autoplay_loop()


func _build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # Block input to scene below

	# Semi-transparent background
	_bg = ColorRect.new()
	_bg.set_anchors_preset(PRESET_FULL_RECT)
	_bg.color = Color(0.0, 0.0, 0.0, 0.5)
	add_child(_bg)

	# Dialogue panel at bottom of screen
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_panel.offset_top = -180.0
	_panel.offset_left = 16.0
	_panel.offset_right = -16.0
	_panel.offset_bottom = -16.0
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	# Character name
	_name_label = Label.new()
	_name_label.text = ""
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", Color(0.9, 0.82, 0.55))
	vbox.add_child(_name_label)

	# Dialogue text
	_text_label = Label.new()
	_text_label.text = ""
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 16)
	_text_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	vbox.add_child(_text_label)

	# "Tap to continue" prompt
	_continue_label = Label.new()
	_continue_label.text = "Tap to continue"
	_continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_label.add_theme_font_size_override("font_size", 12)
	_continue_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
	vbox.add_child(_continue_label)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_tap()
			accept_event()


func _handle_tap() -> void:
	# Cooldown to prevent accidental double-tap
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_tap_time < _tap_cooldown:
		return
	_last_tap_time = now

	if _dialogue_system == null or not _dialogue_system.is_active():
		_dismiss()
		return

	var has_more: bool = _dialogue_system.advance()
	if has_more:
		_show_current_line()
	else:
		_dismiss()


# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------

func _show_current_line() -> void:
	if _dialogue_system == null:
		return

	var line: Dictionary = _dialogue_system.get_current_line()
	if line.is_empty():
		return

	var opponent_id: String = line.get("opponent_id", "")
	var speaker: String = line.get("speaker", "")
	var is_narrator: bool = (opponent_id == "narrator" or (opponent_id == "" and speaker == ""))

	# Apply narrator vs. character styling
	if is_narrator:
		_apply_narrator_style()
	else:
		_apply_character_style(speaker, opponent_id)

	# Dialogue text
	_text_label.text = line.get("text", "")

	# Update continue prompt
	var remaining: int = _dialogue_system._current_lines.size() - _dialogue_system._current_line_index - 1
	if remaining > 0:
		_continue_label.text = "Tap to continue"
	else:
		_continue_label.text = "Tap to dismiss"


## Apply narrator visual style: no name, centered italic text, darker bg.
func _apply_narrator_style() -> void:
	_name_label.text = ""
	_name_label.visible = false
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.add_theme_color_override("font_color", NARRATOR_TEXT_COLOR)
	_text_label.add_theme_font_size_override("font_size", 15)
	_bg.color = NARRATOR_BG_COLOR
	_continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Apply character dialogue style: name label, left-aligned text.
func _apply_character_style(speaker: String, opponent_id: String) -> void:
	if speaker != "":
		_name_label.text = speaker
	else:
		var campaign: Node = get_node_or_null("/root/CampaignSystem")
		if campaign != null:
			var profile: Resource = campaign.get_current_opponent()
			if profile != null and profile.character_name != "":
				_name_label.text = profile.character_name
			else:
				_name_label.text = opponent_id.capitalize()
		else:
			_name_label.text = opponent_id.capitalize()
	_name_label.visible = true
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text_label.add_theme_color_override("font_color", CHARACTER_TEXT_COLOR)
	_text_label.add_theme_font_size_override("font_size", 16)
	_bg.color = CHARACTER_BG_COLOR
	_continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _dismiss() -> void:
	completed.emit()
	queue_free()


## Debug: auto-advance dialogue lines with a delay.
func _autoplay_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(2.5).timeout
		if not is_inside_tree():
			return
		_handle_tap()
