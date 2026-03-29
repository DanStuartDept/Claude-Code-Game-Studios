## GdUnit4 tests for Campaign System
## Covers match progression, chapter advancement, result history, encounter
## counting, save/load round-trip, and signal emission.
##
## See: design/gdd/campaign-system.md
class_name TestCampaignSystem
extends GdUnitTestSuite


const CampaignScript := preload("res://src/core/campaign_system.gd")

var _cs: Node


func before_test() -> void:
	_cs = CampaignScript.new()
	add_child(_cs)
	# Schedule loads automatically via _ready() -> _load_schedule()
	_cs.start_new_campaign()


func after_test() -> void:
	_cs.queue_free()


# --- Helpers ---

## Simulate a player win result.
func _win_result(move_count: int = 25) -> Dictionary:
	return {
		"winner": 1,  # Side.DEFENDER (player always defender)
		"reason": 1,  # WinReason.KING_ESCAPED
		"move_count": move_count,
		"pieces_remaining": {"attacker": 10, "defender": 7},
	}


## Simulate a player loss result.
func _loss_result() -> Dictionary:
	return {
		"winner": 0,  # Side.ATTACKER
		"reason": 2,  # WinReason.KING_CAPTURED
		"move_count": 30,
		"pieces_remaining": {"attacker": 14, "defender": 2},
	}


# ---------------------------------------------------------------------------
# start_new_campaign
# ---------------------------------------------------------------------------

func test_campaign_start_resets_state() -> void:
	assert_bool(_cs.campaign_active).is_true()
	assert_int(_cs.current_chapter).is_equal(0)
	assert_int(_cs.current_match_in_chapter).is_equal(0)
	assert_bool(_cs.campaign_completed_flag).is_false()
	assert_bool(_cs.prologue_completed).is_false()
	assert_dict(_cs.match_history).is_empty()
	assert_dict(_cs.completed_matches).is_empty()
	assert_dict(_cs.encountered_opponents).is_empty()
	assert_dict(_cs.defeated_bosses).is_empty()
	assert_int(_cs.current_loss_streak).is_equal(0)


# ---------------------------------------------------------------------------
# get_current_match_entry
# ---------------------------------------------------------------------------

func test_campaign_first_match_is_prologue_scripted() -> void:
	var entry: Dictionary = _cs.get_current_match_entry()
	assert_str(entry.match_id).is_equal("ch0_scripted")
	assert_str(entry.match_type).is_equal("scripted")
	assert_int(entry.chapter).is_equal(0)


# ---------------------------------------------------------------------------
# process_match_result — scripted loss advances
# ---------------------------------------------------------------------------

func test_campaign_scripted_loss_advances() -> void:
	# Prologue scripted match — loss still advances
	_cs.process_match_result(_loss_result())
	assert_int(_cs.current_match_in_chapter).is_equal(1)
	assert_bool(_cs.completed_matches.has("ch0_scripted")).is_true()


# ---------------------------------------------------------------------------
# process_match_result — win advances
# ---------------------------------------------------------------------------

func test_campaign_win_advances_match() -> void:
	# Skip prologue first
	_cs.process_match_result(_loss_result())  # scripted
	_cs.advance_chapter()  # Move to chapter 1

	# Ch1 match 1: win
	var entry_before: Dictionary = _cs.get_current_match_entry()
	assert_str(entry_before.match_id).is_equal("ch1_match1")

	_cs.process_match_result(_win_result())
	assert_int(_cs.current_match_in_chapter).is_equal(1)

	var entry_after: Dictionary = _cs.get_current_match_entry()
	assert_str(entry_after.match_id).is_equal("ch1_match2")


# ---------------------------------------------------------------------------
# process_match_result — loss stays at same match
# ---------------------------------------------------------------------------

func test_campaign_loss_stays_at_same_match() -> void:
	_cs.process_match_result(_loss_result())  # scripted prologue
	_cs.advance_chapter()

	_cs.process_match_result(_loss_result())  # Lose to ch1_match1
	assert_int(_cs.current_match_in_chapter).is_equal(0)  # Still at match 0
	assert_int(_cs.current_loss_streak).is_equal(1)


# ---------------------------------------------------------------------------
# Loss streak tracking
# ---------------------------------------------------------------------------

func test_campaign_loss_streak_increments_and_resets() -> void:
	_cs.process_match_result(_loss_result())  # scripted prologue
	_cs.advance_chapter()

	_cs.process_match_result(_loss_result())
	assert_int(_cs.current_loss_streak).is_equal(1)

	_cs.process_match_result(_loss_result())
	assert_int(_cs.current_loss_streak).is_equal(2)

	_cs.process_match_result(_win_result())
	assert_int(_cs.current_loss_streak).is_equal(0)


# ---------------------------------------------------------------------------
# Chapter advancement
# ---------------------------------------------------------------------------

func test_campaign_advance_chapter_from_prologue() -> void:
	# Complete prologue (single scripted match)
	_cs.process_match_result(_loss_result())

	assert_bool(_cs.is_chapter_complete()).is_true()
	assert_bool(_cs.can_advance_chapter()).is_true()

	_cs.advance_chapter()
	assert_int(_cs.current_chapter).is_equal(1)
	assert_int(_cs.current_match_in_chapter).is_equal(0)
	assert_bool(_cs.prologue_completed).is_true()


func test_campaign_cannot_advance_without_completing_chapter() -> void:
	# At start of prologue, haven't completed the scripted match yet
	assert_bool(_cs.is_chapter_complete()).is_false()
	assert_bool(_cs.can_advance_chapter()).is_false()


# ---------------------------------------------------------------------------
# Match history and encounter tracking
# ---------------------------------------------------------------------------

func test_campaign_encounter_count_tracks_matches() -> void:
	# Prologue — fight murchadh
	assert_int(_cs.get_encounter_count("murchadh")).is_equal(0)
	_cs.process_match_result(_loss_result())
	assert_int(_cs.get_encounter_count("murchadh")).is_equal(1)


func test_campaign_result_history_no_prior() -> void:
	assert_str(_cs.get_result_history("seanan")).is_equal("no_prior")


func test_campaign_result_history_lost_to_them() -> void:
	_cs.process_match_result(_loss_result())  # prologue
	_cs.advance_chapter()
	_cs.process_match_result(_loss_result())  # lose to seanan
	assert_str(_cs.get_result_history("seanan")).is_equal("lost_to_them")


func test_campaign_result_history_beat_them() -> void:
	_cs.process_match_result(_loss_result())  # prologue
	_cs.advance_chapter()
	_cs.process_match_result(_win_result())  # beat seanan
	assert_str(_cs.get_result_history("seanan")).is_equal("beat_them")


func test_campaign_result_history_mixed() -> void:
	_cs.process_match_result(_loss_result())  # prologue
	_cs.advance_chapter()
	_cs.process_match_result(_loss_result())  # lose to seanan
	_cs.process_match_result(_win_result())  # beat seanan (retry)
	assert_str(_cs.get_result_history("seanan")).is_equal("mixed")


# ---------------------------------------------------------------------------
# Encounter type
# ---------------------------------------------------------------------------

func test_campaign_encounter_type_first() -> void:
	assert_str(_cs.get_encounter_type("seanan")).is_equal("first")


func test_campaign_encounter_type_second() -> void:
	_cs.process_match_result(_loss_result())  # prologue
	_cs.advance_chapter()
	_cs.process_match_result(_loss_result())  # first encounter with seanan
	assert_str(_cs.get_encounter_type("seanan")).is_equal("second")


func test_campaign_encounter_type_third_plus() -> void:
	_cs.process_match_result(_loss_result())  # prologue
	_cs.advance_chapter()
	_cs.process_match_result(_loss_result())  # 1st
	_cs.process_match_result(_loss_result())  # 2nd
	assert_str(_cs.get_encounter_type("seanan")).is_equal("third_plus")


# ---------------------------------------------------------------------------
# has_lost_to
# ---------------------------------------------------------------------------

func test_campaign_has_lost_to_false_initially() -> void:
	assert_bool(_cs.has_lost_to("seanan")).is_false()


func test_campaign_has_lost_to_true_after_loss() -> void:
	_cs.process_match_result(_loss_result())  # prologue
	_cs.advance_chapter()
	_cs.process_match_result(_loss_result())  # lose to seanan
	assert_bool(_cs.has_lost_to("seanan")).is_true()


# ---------------------------------------------------------------------------
# Opponent tracking
# ---------------------------------------------------------------------------

func test_campaign_encountered_opponents_populated() -> void:
	_cs.process_match_result(_loss_result())  # prologue (murchadh)
	assert_bool(_cs.encountered_opponents.has("murchadh")).is_true()


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

func test_campaign_state_changed_signal_on_start() -> void:
	var signal_count: Array = [0]
	_cs.campaign_state_changed.connect(func() -> void: signal_count[0] += 1)
	_cs.start_new_campaign()
	assert_int(signal_count[0]).is_equal(1)


func test_campaign_match_result_processed_signal() -> void:
	var signal_data := []
	_cs.match_result_processed.connect(func(r: Dictionary) -> void: signal_data.append(r))
	_cs.process_match_result(_loss_result())
	assert_int(signal_data.size()).is_equal(1)


func test_campaign_chapter_completed_signal() -> void:
	var signal_data := []
	_cs.chapter_completed.connect(func(ch: int) -> void: signal_data.append(ch))

	_cs.process_match_result(_loss_result())  # complete prologue
	_cs.advance_chapter()

	assert_int(signal_data.size()).is_equal(1)
	assert_int(signal_data[0]).is_equal(0)  # chapter 0 completed


# ---------------------------------------------------------------------------
# Save / Load round-trip
# ---------------------------------------------------------------------------

func test_campaign_save_load_round_trip() -> void:
	# Progress through prologue and into chapter 1
	_cs.process_match_result(_loss_result())  # prologue scripted
	_cs.advance_chapter()
	_cs.process_match_result(_win_result())  # beat ch1_match1

	var save_data: Dictionary = _cs.get_save_data()

	# Verify save data has expected fields
	assert_int(save_data.current_chapter).is_equal(1)
	assert_int(save_data.current_match_in_chapter).is_equal(1)
	assert_bool(save_data.prologue_completed).is_true()
	assert_bool(save_data.campaign_active).is_true()

	# Reset and load
	_cs.start_new_campaign()
	assert_int(_cs.current_chapter).is_equal(0)

	_cs.load_save_data(save_data)
	assert_int(_cs.current_chapter).is_equal(1)
	assert_int(_cs.current_match_in_chapter).is_equal(1)
	assert_bool(_cs.prologue_completed).is_true()


# ---------------------------------------------------------------------------
# Chapter info queries
# ---------------------------------------------------------------------------

func test_campaign_get_current_chapter_info() -> void:
	var info: Dictionary = _cs.get_current_chapter_info()
	assert_str(info.name).is_equal("Prologue: The Disgrace")


func test_campaign_chapter_match_count() -> void:
	# Prologue has 1 match (ch0_scripted)
	assert_int(_cs.get_chapter_match_count()).is_equal(1)

	_cs.process_match_result(_loss_result())
	_cs.advance_chapter()

	# Chapter 1 has 4 matches
	assert_int(_cs.get_chapter_match_count()).is_equal(4)


# ---------------------------------------------------------------------------
# Edge case: empty match entry at end of chapter
# ---------------------------------------------------------------------------

func test_campaign_get_current_match_entry_empty_at_chapter_end() -> void:
	_cs.process_match_result(_loss_result())  # complete prologue
	# Now current_match_in_chapter = 1 but prologue only has 1 match
	var entry: Dictionary = _cs.get_current_match_entry()
	assert_dict(entry).is_empty()
