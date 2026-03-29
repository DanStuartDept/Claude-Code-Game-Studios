## Main Menu — Title screen with campaign and quick play options.
##
## See: production/sprints/sprint-02.md (S2-09, S2-16)
extends Control


## All opponent profile paths for Quick Play.
const OPPONENT_DIR: String = "res://assets/data/opponents/"


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
	vbox.offset_top = -180.0
	vbox.offset_bottom = 180.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
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

	# Campaign button
	var campaign_button := Button.new()
	campaign_button.text = "New Campaign"
	campaign_button.pressed.connect(_on_campaign_pressed)
	campaign_button.custom_minimum_size = Vector2(200, 50)
	vbox.add_child(campaign_button)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer2)

	# Quick play section — dynamically list all opponents
	var quick_label := Label.new()
	quick_label.text = "Quick Play"
	quick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quick_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.38))
	vbox.add_child(quick_label)

	_populate_opponent_buttons(vbox)

	# Register scenes
	var scene_manager: Node = get_node_or_null("/root/SceneManager")
	if scene_manager != null:
		scene_manager.register_scene(&"match", "res://scenes/match/Match.tscn")
		scene_manager.register_scene(&"menu", "res://scenes/menu/MainMenu.tscn")
		scene_manager.register_scene(&"campaign_map", "res://scenes/campaign/CampaignMap.tscn")

	# Auto-play: skip menu and go straight to campaign
	if OS.get_cmdline_args().has("--autoplay") or OS.get_cmdline_user_args().has("--autoplay"):
		print("[MENU] Auto-play detected, launching campaign...")
		_on_campaign_pressed()


## Scan opponent directory and create a button for each profile.
func _populate_opponent_buttons(parent: VBoxContainer) -> void:
	var dir := DirAccess.open(OPPONENT_DIR)
	if dir == null:
		return

	# Collect and sort profiles by difficulty
	var profiles: Array[Dictionary] = []
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path: String = OPPONENT_DIR + file_name
			var profile: Resource = load(path)
			if profile != null:
				profiles.append({
					"path": path,
					"name": profile.character_name,
					"difficulty": profile.difficulty,
				})
		file_name = dir.get_next()
	dir.list_dir_end()

	profiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.difficulty < b.difficulty)

	for p: Dictionary in profiles:
		var button := Button.new()
		button.text = "vs %s" % p.name
		button.pressed.connect(_launch_quick_play.bind(p.path))
		button.custom_minimum_size = Vector2(200, 36)
		parent.add_child(button)


func _on_campaign_pressed() -> void:
	var scene_manager: Node = get_node_or_null("/root/SceneManager")
	if scene_manager != null:
		# Reset campaign and reputation for new game
		var campaign: Node = get_node_or_null("/root/CampaignSystem")
		if campaign != null:
			campaign.start_new_campaign()
		var rep: Node = get_node_or_null("/root/ReputationSystem")
		if rep != null:
			rep.reset()

		scene_manager.scene_data = { "show_narrator": true, "narrator_id": "narrator_ch0_start" }
		visible = false
		scene_manager.change_scene(&"campaign_map")
		queue_free()


func _launch_quick_play(profile_path: String) -> void:
	var scene_manager: Node = get_node_or_null("/root/SceneManager")
	if scene_manager != null:
		scene_manager.scene_data = {
			"opponent_profile_path": profile_path,
			"campaign_mode": false,
		}
		visible = false
		scene_manager.change_scene(&"match")
		queue_free()
	else:
		get_tree().change_scene_to_file("res://scenes/match/Match.tscn")
