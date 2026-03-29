## Main Menu — Simple title screen with Play button.
##
## Launches a match against Seanán via SceneManager.
## See: production/sprints/sprint-01.md (S1-10)
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
	vbox.offset_top = -80.0
	vbox.offset_bottom = 80.0
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

	var play_button := Button.new()
	play_button.text = "Play vs Seanán"
	play_button.pressed.connect(_on_play_pressed)
	play_button.custom_minimum_size = Vector2(200, 50)
	vbox.add_child(play_button)

	# Register scenes
	var scene_manager: Node = get_node_or_null("/root/SceneManager")
	if scene_manager != null:
		scene_manager.register_scene(&"match", "res://scenes/match/Match.tscn")
		scene_manager.register_scene(&"menu", "res://scenes/menu/MainMenu.tscn")

	# Auto-play: skip menu and go straight to match
	if OS.get_cmdline_args().has("--autoplay") or OS.get_cmdline_user_args().has("--autoplay"):
		print("[MENU] Auto-play detected, launching match...")
		_on_play_pressed()


func _on_play_pressed() -> void:
	var scene_manager: Node = get_node_or_null("/root/SceneManager")
	if scene_manager != null:
		# Hide immediately — SceneManager loads Match into its own SceneRoot,
		# but Godot's main scene (this node) stays in the tree as a root child.
		# We must remove ourselves so we don't sit on top of the Match scene.
		visible = false
		scene_manager.change_scene(&"match")
		queue_free()
	else:
		# Fallback: load match scene directly
		get_tree().change_scene_to_file("res://scenes/match/Match.tscn")
