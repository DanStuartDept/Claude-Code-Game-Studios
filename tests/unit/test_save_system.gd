## GdUnit4 tests for Save System
## Covers save/load round-trip, corrupt file handling, version validation,
## backup creation, and delete.
##
## See: design/gdd/save-system.md
class_name TestSaveSystem
extends GdUnitTestSuite


const SaveScript := preload("res://src/core/save_system.gd")

var _save: Node


func before_test() -> void:
	_save = SaveScript.new()
	add_child(_save)
	# Clean up any test save files
	_cleanup_save_files()


func after_test() -> void:
	_cleanup_save_files()
	_save.queue_free()


func _cleanup_save_files() -> void:
	if FileAccess.file_exists("user://fidchell_save.json"):
		DirAccess.remove_absolute("user://fidchell_save.json")
	if FileAccess.file_exists("user://fidchell_save.backup.json"):
		DirAccess.remove_absolute("user://fidchell_save.backup.json")


# ---------------------------------------------------------------------------
# has_save
# ---------------------------------------------------------------------------

func test_save_has_save_false_when_no_file() -> void:
	assert_bool(_save.has_save()).is_false()


func test_save_has_save_true_after_save() -> void:
	_save.save_game()
	assert_bool(_save.has_save()).is_true()


# ---------------------------------------------------------------------------
# save_game / load_game round-trip
# ---------------------------------------------------------------------------

func test_save_round_trip_creates_file() -> void:
	var result: bool = _save.save_game()
	assert_bool(result).is_true()
	assert_bool(FileAccess.file_exists("user://fidchell_save.json")).is_true()


func test_save_file_contains_valid_json() -> void:
	_save.save_game()

	var file: FileAccess = FileAccess.open("user://fidchell_save.json", FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	assert_int(json.parse(text)).is_equal(OK)
	assert_bool(json.data is Dictionary).is_true()


func test_save_file_contains_version() -> void:
	_save.save_game()

	var file: FileAccess = FileAccess.open("user://fidchell_save.json", FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	json.parse(text)
	var data: Dictionary = json.data
	assert_int(int(data.get("save_version", 0))).is_equal(1)


func test_save_file_contains_timestamp() -> void:
	_save.save_game()

	var file: FileAccess = FileAccess.open("user://fidchell_save.json", FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	json.parse(text)
	var data: Dictionary = json.data
	assert_bool(data.has("timestamp")).is_true()


func test_save_load_returns_true() -> void:
	_save.save_game()
	var result: bool = _save.load_game()
	assert_bool(result).is_true()


# ---------------------------------------------------------------------------
# Backup
# ---------------------------------------------------------------------------

func test_save_creates_backup_on_second_save() -> void:
	_save.save_game()
	assert_bool(FileAccess.file_exists("user://fidchell_save.backup.json")).is_false()

	_save.save_game()
	assert_bool(FileAccess.file_exists("user://fidchell_save.backup.json")).is_true()


# ---------------------------------------------------------------------------
# Corrupt file handling
# ---------------------------------------------------------------------------

func test_save_load_rejects_corrupt_json() -> void:
	var file: FileAccess = FileAccess.open("user://fidchell_save.json", FileAccess.WRITE)
	file.store_string("{ this is not valid json }")
	file.close()

	var error_msgs := []
	_save.save_error.connect(func(msg: String) -> void: error_msgs.append(msg))

	var result: bool = _save.load_game()
	assert_bool(result).is_false()
	assert_int(error_msgs.size()).is_equal(1)


func test_save_load_rejects_non_dict_json() -> void:
	var file: FileAccess = FileAccess.open("user://fidchell_save.json", FileAccess.WRITE)
	file.store_string("[1, 2, 3]")
	file.close()

	var result: bool = _save.load_game()
	assert_bool(result).is_false()


# ---------------------------------------------------------------------------
# Version validation
# ---------------------------------------------------------------------------

func test_save_load_rejects_future_version() -> void:
	var data: Dictionary = {"save_version": 999}
	var file: FileAccess = FileAccess.open("user://fidchell_save.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

	var error_msgs := []
	_save.save_error.connect(func(msg: String) -> void: error_msgs.append(msg))

	var result: bool = _save.load_game()
	assert_bool(result).is_false()
	assert_bool(error_msgs[0].contains("newer version")).is_true()


func test_save_load_rejects_zero_version() -> void:
	var data: Dictionary = {"save_version": 0}
	var file: FileAccess = FileAccess.open("user://fidchell_save.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

	var result: bool = _save.load_game()
	assert_bool(result).is_false()


# ---------------------------------------------------------------------------
# delete_save
# ---------------------------------------------------------------------------

func test_save_delete_removes_files() -> void:
	_save.save_game()
	_save.save_game()  # Creates backup
	assert_bool(FileAccess.file_exists("user://fidchell_save.json")).is_true()
	assert_bool(FileAccess.file_exists("user://fidchell_save.backup.json")).is_true()

	_save.delete_save()
	assert_bool(FileAccess.file_exists("user://fidchell_save.json")).is_false()
	assert_bool(FileAccess.file_exists("user://fidchell_save.backup.json")).is_false()


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

func test_save_game_saved_signal_emits() -> void:
	var signal_count: Array = [0]
	_save.game_saved.connect(func() -> void: signal_count[0] += 1)

	_save.save_game()
	assert_int(signal_count[0]).is_equal(1)


func test_save_game_loaded_signal_emits() -> void:
	_save.save_game()

	var signal_count: Array = [0]
	_save.game_loaded.connect(func() -> void: signal_count[0] += 1)

	_save.load_game()
	assert_int(signal_count[0]).is_equal(1)


# ---------------------------------------------------------------------------
# get_save_data_preview
# ---------------------------------------------------------------------------

func test_save_data_preview_returns_dict() -> void:
	var preview: Dictionary = _save.get_save_data_preview()
	assert_bool(preview.has("save_version")).is_true()
	assert_bool(preview.has("timestamp")).is_true()


# ---------------------------------------------------------------------------
# No file = load fails gracefully
# ---------------------------------------------------------------------------

func test_save_load_returns_false_when_no_file() -> void:
	var result: bool = _save.load_game()
	assert_bool(result).is_false()
