## Main Menu — Simple title screen with opponent selection.
##
## Launches a match against a selected opponent via SceneManager.
## See: production/sprints/sprint-01.md (S1-10, S1-16)
class_name MainMenu
extends Control


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.12, 0.09, 0.06)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_CENTER)
	vbox.offset_left = -120.0
	vbox.offset_right = 120.0
	vbox.offset_top = -120.0
	vbox.offset_bottom = 120.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	var title := Label.new()
	title.text = "Fidchell"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.82, 0.55))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A Game of Kings and Cunning"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	# Opponent buttons
	_add_opponent_button(vbox, "Play vs Seanan", "res://assets/data/opponents/seanan.tres")
	_add_opponent_button(vbox, "Play vs Brigid", "res://assets/data/opponents/brigid.tres")

	# Register scenes
	var scene_manager: Node = get_node_or_null("/root/SceneManager")
	if scene_manager != null:
		scene_manager.register_scene(&"match", "res://scenes/match/Match.tscn")
		scene_manager.register_scene(&"menu", "res://scenes/menu/MainMenu.tscn")

	# Auto-play: skip menu and go straight to match
	if OS.get_cmdline_args().has("--autoplay") or OS.get_cmdline_user_args().has("--autoplay"):
		print("[MENU] Auto-play detected, launching match...")
		_launch_match("res://assets/data/opponents/seanan.tres")


func _add_opponent_button(parent: VBoxContainer, text: String, profile_path: String) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(_launch_match.bind(profile_path))
	button.custom_minimum_size = Vector2(200, 50)
	parent.add_child(button)


func _launch_match(profile_path: String) -> void:
	var scene_manager: Node = get_node_or_null("/root/SceneManager")
	if scene_manager != null:
		scene_manager.scene_data = { "opponent_profile_path": profile_path }
		visible = false
		scene_manager.change_scene(&"match")
		queue_free()
	else:
		get_tree().change_scene_to_file("res://scenes/match/Match.tscn")
