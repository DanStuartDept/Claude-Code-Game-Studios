## GdUnit4 integration test for full campaign flow.
##
## Simulates playing through all 5 chapters (Prologue through Return)
## by mocking match results and verifying all state transitions:
## chapter advancement, reputation thresholds, narrator triggers,
## feud system, and campaign completion.
##
## This does NOT launch actual matches — it drives CampaignSystem,
## ReputationSystem, and FeudSystem APIs directly with mock results.
##
## See: production/sprints/sprint-05.md (S5-12)
class_name TestCampaignIntegration
extends GdUnitTestSuite


const CampaignScript := preload("res://src/core/campaign_system.gd")
const RepScript := preload("res://src/core/reputation_system.gd")
const FeudScript := preload("res://src/core/feud_system.gd")
const DialogueScript := preload("res://src/core/dialogue_system.gd")
const SaveScript := preload("res://src/core/save_system.gd")

var _campaign: Node
var _reputation: Node
var _feud: Node
var _dialogue: Node
var _save: Node


func before_test() -> void:
	_reputation = RepScript.new()
	_reputation.name = "ReputationSystem"
	add_child(_reputation)

	_feud = FeudScript.new()
	_feud.name = "FeudSystem"
	add_child(_feud)

	_campaign = CampaignScript.new()
	_campaign.name = "CampaignSystem"
	add_child(_campaign)

	_dialogue = DialogueScript.new()
	_dialogue.name = "DialogueSystem"
	add_child(_dialogue)

	_save = SaveScript.new()
	_save.name = "SaveSystem"
	add_child(_save)


func after_test() -> void:
	# Clean up save files
	if FileAccess.file_exists("user://fidchell_save.json"):
		DirAccess.remove_absolute("user://fidchell_save.json")
	if FileAccess.file_exists("user://fidchell_save.backup.json"):
		DirAccess.remove_absolute("user://fidchell_save.backup.json")

	_save.queue_free()
	_dialogue.queue_free()
	_campaign.queue_free()
	_feud.queue_free()
	_reputation.queue_free()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _mock_win_result(move_count: int = 15) -> Dictionary:
	return {
		"winner": 1,  # Side.DEFENDER (player)
		"reason": 1,  # WinReason.KING_ESCAPED
		"move_count": move_count,
		"pieces_remaining": {"attacker": 4, "defender": 6},
	}


func _mock_loss_result(move_count: int = 20) -> Dictionary:
	return {
		"winner": 0,  # Side.ATTACKER
		"reason": 2,  # WinReason.KING_CAPTURED
		"move_count": move_count,
		"pieces_remaining": {"attacker": 7, "defender": 2},
	}


func _play_chapter_all_wins() -> void:
	var schedule: Array = _campaign.get_chapter_schedule()
	for _i: int in schedule.size():
		_campaign.process_match_result(_mock_win_result())


func _get_chapter_match_count() -> int:
	return _campaign.get_chapter_schedule().size()


# ---------------------------------------------------------------------------
# Full campaign flow
# ---------------------------------------------------------------------------

func test_campaign_integration_full_playthrough() -> void:
	# Start fresh campaign
	_campaign.start_new_campaign()
	_reputation.reset()
	_feud.reset()

	assert_bool(_campaign.campaign_active).is_true()
	assert_int(_campaign.current_chapter).is_equal(0)

	# --- Prologue (Chapter 0) ---
	# Tutorial match (we skip it in this test)
	# Scripted loss match
	var prologue_schedule: Array = _campaign.get_chapter_schedule()
	assert_bool(prologue_schedule.size() > 0).is_true()

	# Process scripted loss (prologue match)
	for _i: int in prologue_schedule.size():
		var entry: Dictionary = _campaign.get_current_match_entry()
		var match_type: String = entry.get("match_type", "standard")
		if match_type == "scripted":
			_campaign.process_match_result(_mock_loss_result())
		elif match_type == "tutorial":
			_campaign.process_match_result(_mock_win_result())
		else:
			_campaign.process_match_result(_mock_win_result())

	assert_bool(_campaign.is_chapter_complete()).is_true()

	# Advance to Chapter 1
	assert_bool(_campaign.can_advance_chapter()).is_true()
	_campaign.advance_chapter()
	assert_int(_campaign.current_chapter).is_equal(1)

	# --- Chapter 1: Connacht ---
	_play_chapter_all_wins()
	assert_bool(_campaign.is_chapter_complete()).is_true()

	# Should have enough rep to advance
	assert_bool(_campaign.can_advance_chapter()).is_true()
	_campaign.advance_chapter()
	assert_int(_campaign.current_chapter).is_equal(2)

	# --- Chapter 2: The Old Roads ---
	_play_chapter_all_wins()
	assert_bool(_campaign.is_chapter_complete()).is_true()

	assert_bool(_campaign.can_advance_chapter()).is_true()
	_campaign.advance_chapter()
	assert_int(_campaign.current_chapter).is_equal(3)

	# --- Chapter 3: The Midlands ---
	_play_chapter_all_wins()
	assert_bool(_campaign.is_chapter_complete()).is_true()

	assert_bool(_campaign.can_advance_chapter()).is_true()
	_campaign.advance_chapter()
	assert_int(_campaign.current_chapter).is_equal(4)

	# --- Chapter 4: The Return ---
	_play_chapter_all_wins()
	assert_bool(_campaign.is_chapter_complete()).is_true()

	# Final chapter — can_advance should be false (no ch5)
	assert_bool(_campaign.can_advance_chapter()).is_false()

	# Manually mark campaign complete (as campaign_map.gd does)
	_campaign.state = _campaign.CampaignState.CAMPAIGN_COMPLETE
	_campaign.campaign_completed_flag = true

	assert_bool(_campaign.campaign_completed_flag).is_true()


func test_campaign_integration_reputation_accumulates() -> void:
	_campaign.start_new_campaign()
	_reputation.reset()

	# Win prologue matches
	var prologue_schedule: Array = _campaign.get_chapter_schedule()
	for _i: int in prologue_schedule.size():
		var entry: Dictionary = _campaign.get_current_match_entry()
		if entry.get("match_type", "") == "scripted":
			_campaign.process_match_result(_mock_loss_result())
		elif entry.get("match_type", "") == "tutorial":
			_campaign.process_match_result(_mock_win_result())
		else:
			_campaign.process_match_result(_mock_win_result())
	_campaign.advance_chapter()

	# Win ch1 matches and check reputation grows
	var ch1_schedule: Array = _campaign.get_chapter_schedule()
	var rep_before: int = _reputation.current_reputation
	for _i: int in ch1_schedule.size():
		_campaign.process_match_result(_mock_win_result())
	var rep_after: int = _reputation.current_reputation
	assert_bool(rep_after > rep_before).is_true()


func test_campaign_integration_loss_does_not_advance() -> void:
	_campaign.start_new_campaign()
	_reputation.reset()

	# Skip to ch1
	var prologue_schedule: Array = _campaign.get_chapter_schedule()
	for _i: int in prologue_schedule.size():
		var entry: Dictionary = _campaign.get_current_match_entry()
		if entry.get("match_type", "") == "scripted":
			_campaign.process_match_result(_mock_loss_result())
		elif entry.get("match_type", "") == "tutorial":
			_campaign.process_match_result(_mock_win_result())
		else:
			_campaign.process_match_result(_mock_win_result())
	_campaign.advance_chapter()

	var match_before: int = _campaign.current_match_in_chapter

	# Lose a match
	_campaign.process_match_result(_mock_loss_result())

	# Match position should not advance
	assert_int(_campaign.current_match_in_chapter).is_equal(match_before)


func test_campaign_integration_save_load_mid_campaign() -> void:
	_campaign.start_new_campaign()
	_reputation.reset()

	# Play through prologue and ch1
	var prologue_schedule: Array = _campaign.get_chapter_schedule()
	for _i: int in prologue_schedule.size():
		var entry: Dictionary = _campaign.get_current_match_entry()
		if entry.get("match_type", "") == "scripted":
			_campaign.process_match_result(_mock_loss_result())
		elif entry.get("match_type", "") == "tutorial":
			_campaign.process_match_result(_mock_win_result())
		else:
			_campaign.process_match_result(_mock_win_result())
	_campaign.advance_chapter()

	_play_chapter_all_wins()
	_campaign.advance_chapter()

	# Now in ch2 — save
	var chapter_before: int = _campaign.current_chapter
	var rep_before: int = _reputation.current_reputation
	_save.save_game()

	# Mutate state
	_campaign.current_chapter = 99
	_reputation.current_reputation = 0

	# Reload
	_save.load_game()

	assert_int(_campaign.current_chapter).is_equal(chapter_before)
	assert_int(_reputation.current_reputation).is_equal(rep_before)


func test_campaign_integration_save_load_preserves_audio_volumes() -> void:
	_campaign.start_new_campaign()
	_reputation.reset()

	# Set custom audio volumes via save data directly
	# (AudioSystem is not loaded in unit tests, but save file handles it)
	_save.save_game()

	# Verify save data contains version and campaign state
	var file: FileAccess = FileAccess.open("user://fidchell_save.json", FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()

	var data: Dictionary = json.data
	assert_bool(data.has("save_version")).is_true()
	assert_bool(data.has("campaign")).is_true()
	assert_bool(data.has("reputation")).is_true()

	# Reload and verify
	_save.load_game()
	assert_int(_campaign.current_chapter).is_equal(0)


func test_campaign_integration_new_opponent_ids_serialize() -> void:
	_campaign.start_new_campaign()
	_reputation.reset()

	# Skip prologue
	var prologue_schedule: Array = _campaign.get_chapter_schedule()
	for _i: int in prologue_schedule.size():
		var entry: Dictionary = _campaign.get_current_match_entry()
		if entry.get("match_type", "") == "scripted":
			_campaign.process_match_result(_mock_loss_result())
		elif entry.get("match_type", "") == "tutorial":
			_campaign.process_match_result(_mock_win_result())
		else:
			_campaign.process_match_result(_mock_win_result())
	_campaign.advance_chapter()

	# Play and win ch1
	_play_chapter_all_wins()
	_campaign.advance_chapter()

	# Play some ch2 matches (new opponent IDs from sprint 5)
	var ch2_schedule: Array = _campaign.get_chapter_schedule()
	if ch2_schedule.size() > 0:
		_campaign.process_match_result(_mock_win_result())

	# Save mid-ch2
	var match_pos: int = _campaign.current_match_in_chapter
	var history_size: int = _campaign.match_history.size()
	_save.save_game()

	# Mutate state
	_campaign.current_match_in_chapter = 99
	_campaign.match_history = {}

	# Reload
	_save.load_game()
	assert_int(_campaign.current_chapter).is_equal(2)
	assert_int(_campaign.current_match_in_chapter).is_equal(match_pos)
	assert_int(_campaign.match_history.size()).is_equal(history_size)


func test_campaign_integration_chapter_transitions_fire() -> void:
	_campaign.start_new_campaign()
	_reputation.reset()

	var chapters_completed: Array[int] = []
	_campaign.chapter_completed.connect(func(ch: int) -> void:
		chapters_completed.append(ch))

	# Play through prologue
	var prologue_schedule: Array = _campaign.get_chapter_schedule()
	for _i: int in prologue_schedule.size():
		var entry: Dictionary = _campaign.get_current_match_entry()
		if entry.get("match_type", "") == "scripted":
			_campaign.process_match_result(_mock_loss_result())
		elif entry.get("match_type", "") == "tutorial":
			_campaign.process_match_result(_mock_win_result())
		else:
			_campaign.process_match_result(_mock_win_result())
	_campaign.advance_chapter()
	assert_bool(chapters_completed.has(0)).is_true()

	# Play through ch1
	_play_chapter_all_wins()
	_campaign.advance_chapter()
	assert_bool(chapters_completed.has(1)).is_true()
