## Save System — Persists campaign progress between sessions.
##
## Auto-saves after match results and chapter transitions. Serializes state from
## CampaignSystem and ReputationSystem into a single JSON file. Supports backup,
## versioning, and corrupt-file recovery.
##
## Architecture: Feature Layer (ADR-0001). Depends on Campaign System, Reputation System.
## See: design/gdd/save-system.md
##
## Usage (Autoload — accessed globally):
##   SaveSystem.save_game()
##   SaveSystem.load_game() -> bool
##   SaveSystem.has_save() -> bool
extends Node


# --- Signals ---

## Emitted after a successful save.
signal game_saved()

## Emitted after a successful load.
signal game_loaded()

## Emitted when save/load encounters an error.
signal save_error(message: String)


# --- Constants ---

const SAVE_PATH: String = "user://fidchell_save.json"
const BACKUP_PATH: String = "user://fidchell_save.backup.json"
const CURRENT_SAVE_VERSION: int = 1


# --- State ---

## True while a save operation is in progress (prevents re-entrant saves).
var _saving: bool = false


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_connect_auto_save_signals()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Check if a save file exists on disk.
##
## Usage:
##   if SaveSystem.has_save():
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Save the current game state to disk.
## Creates a backup of the existing save before writing.
##
## Usage:
##   SaveSystem.save_game()
func save_game() -> bool:
	if _saving:
		return false
	_saving = true

	var data: Dictionary = _build_save_data()
	var json_string: String = JSON.stringify(data, "\t")

	# Create backup of existing save
	if FileAccess.file_exists(SAVE_PATH):
		var existing: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if existing != null:
			var backup_content: String = existing.get_as_text()
			existing.close()
			var backup: FileAccess = FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if backup != null:
				backup.store_string(backup_content)
				backup.close()

	# Write save file
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		var err_msg: String = "Failed to open save file for writing"
		push_error("SaveSystem: %s" % err_msg)
		save_error.emit(err_msg)
		_saving = false
		return false

	file.store_string(json_string)
	file.close()

	_saving = false
	game_saved.emit()
	return true


## Load game state from the save file. Returns true on success.
## Restores state to CampaignSystem and ReputationSystem.
##
## Usage:
##   if SaveSystem.load_game():
##       # State restored, transition to campaign map
func load_game() -> bool:
	if not has_save():
		return false

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		save_error.emit("Failed to open save file for reading")
		return false

	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var err: Error = json.parse(json_text)
	if err != OK:
		var err_msg: String = "Corrupted save file: %s" % json.get_error_message()
		push_error("SaveSystem: %s" % err_msg)
		save_error.emit(err_msg)
		return false

	var data: Variant = json.data
	if not data is Dictionary:
		save_error.emit("Save file has invalid format")
		return false

	# Version check
	var save_version: int = int(data.get("save_version", 0))
	if save_version > CURRENT_SAVE_VERSION:
		save_error.emit("Save was created by a newer version of the game")
		return false

	if save_version < 1:
		save_error.emit("Save file has invalid version")
		return false

	# Migrate if needed (future: add migration functions here)
	# if save_version < 2: data = _migrate_v1_to_v2(data)

	# Restore campaign state
	var campaign: Node = get_node_or_null("/root/CampaignSystem")
	if campaign != null and data.has("campaign"):
		campaign.load_save_data(data.campaign)

	# Restore reputation state
	var rep: Node = get_node_or_null("/root/ReputationSystem")
	if rep != null and data.has("reputation"):
		rep.load_save_data(data.reputation)

	# Restore feud state
	var feud: Node = get_node_or_null("/root/FeudSystem")
	if feud != null and data.has("feud"):
		feud.load_feud_data(data.feud)

	# Restore audio settings
	var audio: Node = get_node_or_null("/root/AudioSystem")
	if audio != null and data.has("audio_volumes"):
		audio.restore_volumes(data.audio_volumes)

	game_loaded.emit()
	return true


## Delete the save file (for New Game).
##
## Usage:
##   SaveSystem.delete_save()
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(BACKUP_PATH)


## Get the save data as a dictionary (for testing/inspection without writing).
func get_save_data_preview() -> Dictionary:
	return _build_save_data()


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _build_save_data() -> Dictionary:
	var data: Dictionary = {
		"save_version": CURRENT_SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(true),
	}

	# Campaign state
	var campaign: Node = get_node_or_null("/root/CampaignSystem")
	if campaign != null:
		data["campaign"] = campaign.get_save_data()

	# Reputation state
	var rep: Node = get_node_or_null("/root/ReputationSystem")
	if rep != null:
		data["reputation"] = rep.get_save_data()

	# Feud state
	var feud: Node = get_node_or_null("/root/FeudSystem")
	if feud != null:
		data["feud"] = feud.get_all_feud_data()

	# Audio settings
	var audio: Node = get_node_or_null("/root/AudioSystem")
	if audio != null:
		data["audio_volumes"] = audio.get_all_volumes()

	return data


func _connect_auto_save_signals() -> void:
	# Deferred connection — autoloads may not be ready yet
	call_deferred("_bind_auto_save")


func _bind_auto_save() -> void:
	var campaign: Node = get_node_or_null("/root/CampaignSystem")
	if campaign != null:
		if campaign.has_signal("match_result_processed"):
			campaign.match_result_processed.connect(_on_auto_save_trigger)
		if campaign.has_signal("chapter_completed"):
			campaign.chapter_completed.connect(_on_chapter_auto_save)
		if campaign.has_signal("campaign_completed"):
			campaign.campaign_completed.connect(_on_auto_save_trigger)


func _on_auto_save_trigger(_arg: Variant = null) -> void:
	save_game()


func _on_chapter_auto_save(_chapter_index: int) -> void:
	save_game()
