## GdUnit4 tests for Reputation System
## Covers award_match_win (all bonus paths), tier lookup, config loading, reset,
## and save/load round-trip.
##
## See: design/gdd/reputation-system.md
class_name TestReputationSystem
extends GdUnitTestSuite


const ReputationScript := preload("res://src/core/reputation_system.gd")

var _rep: Node


func before_test() -> void:
	_rep = ReputationScript.new()
	add_child(_rep)


func after_test() -> void:
	_rep.queue_free()


# --- Helpers ---

func _make_context(overrides: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = {
		"move_count": 25,
		"defender_pieces": 3,
		"is_chapter_boss": false,
		"is_feud_win": false,
		"is_nemesis_win": false,
		"is_rematch_win": false,
		"opponent_id": "test_opponent",
	}
	for key: String in overrides:
		ctx[key] = overrides[key]
	return ctx


# ---------------------------------------------------------------------------
# Base win award
# ---------------------------------------------------------------------------

func test_reputation_award_base_win_adds_five() -> void:
	var breakdown: Dictionary = _rep.award_match_win(_make_context())
	assert_int(_rep.get_reputation()).is_equal(5)
	assert_bool(breakdown.has("base")).is_true()
	assert_int(breakdown.base).is_equal(5)


# ---------------------------------------------------------------------------
# Speed bonus
# ---------------------------------------------------------------------------

func test_reputation_speed_bonus_awarded_under_threshold() -> void:
	var breakdown: Dictionary = _rep.award_match_win(_make_context({"move_count": 15}))
	assert_bool(breakdown.has("speed")).is_true()
	assert_int(breakdown.speed).is_equal(2)
	assert_int(_rep.get_reputation()).is_equal(7)


func test_reputation_speed_bonus_awarded_at_threshold() -> void:
	var breakdown: Dictionary = _rep.award_match_win(_make_context({"move_count": 20}))
	assert_bool(breakdown.has("speed")).is_true()


func test_reputation_speed_bonus_not_awarded_over_threshold() -> void:
	var breakdown: Dictionary = _rep.award_match_win(_make_context({"move_count": 21}))
	assert_bool(breakdown.has("speed")).is_false()


# ---------------------------------------------------------------------------
# Decisive bonus
# ---------------------------------------------------------------------------

func test_reputation_decisive_bonus_awarded_at_threshold() -> void:
	var breakdown: Dictionary = _rep.award_match_win(_make_context({"defender_pieces": 5}))
	assert_bool(breakdown.has("decisive")).is_true()
	assert_int(breakdown.decisive).is_equal(1)


func test_reputation_decisive_bonus_not_awarded_below_threshold() -> void:
	var breakdown: Dictionary = _rep.award_match_win(_make_context({"defender_pieces": 4}))
	assert_bool(breakdown.has("decisive")).is_false()


# ---------------------------------------------------------------------------
# Boss bonus
# ---------------------------------------------------------------------------

func test_reputation_boss_bonus_awarded() -> void:
	var breakdown: Dictionary = _rep.award_match_win(_make_context({"is_chapter_boss": true}))
	assert_bool(breakdown.has("boss")).is_true()
	assert_int(breakdown.boss).is_equal(3)


func test_reputation_boss_bonus_not_awarded_for_normal_match() -> void:
	var breakdown: Dictionary = _rep.award_match_win(_make_context({"is_chapter_boss": false}))
	assert_bool(breakdown.has("boss")).is_false()


# ---------------------------------------------------------------------------
# Feud bonus
# ---------------------------------------------------------------------------

func test_reputation_feud_bonus_awarded() -> void:
	var breakdown: Dictionary = _rep.award_match_win(_make_context({"is_feud_win": true}))
	assert_bool(breakdown.has("feud")).is_true()
	assert_int(breakdown.feud).is_equal(3)


# ---------------------------------------------------------------------------
# Nemesis bonus
# ---------------------------------------------------------------------------

func test_reputation_nemesis_bonus_awarded() -> void:
	var breakdown: Dictionary = _rep.award_match_win(_make_context({"is_nemesis_win": true}))
	assert_bool(breakdown.has("nemesis")).is_true()
	assert_int(breakdown.nemesis).is_equal(5)


# ---------------------------------------------------------------------------
# Rematch bonus
# ---------------------------------------------------------------------------

func test_reputation_rematch_bonus_awarded() -> void:
	var breakdown: Dictionary = _rep.award_match_win(_make_context({"is_rematch_win": true}))
	assert_bool(breakdown.has("rematch")).is_true()
	assert_int(breakdown.rematch).is_equal(1)


# ---------------------------------------------------------------------------
# Stacking bonuses
# ---------------------------------------------------------------------------

func test_reputation_all_bonuses_stack() -> void:
	var ctx: Dictionary = _make_context({
		"move_count": 15,
		"defender_pieces": 6,
		"is_chapter_boss": true,
		"is_feud_win": true,
		"is_nemesis_win": true,
		"is_rematch_win": true,
	})
	_rep.award_match_win(ctx)
	# base(5) + speed(2) + decisive(1) + boss(3) + feud(3) + nemesis(5) + rematch(1) = 20
	assert_int(_rep.get_reputation()).is_equal(20)


# ---------------------------------------------------------------------------
# Reputation never decreases
# ---------------------------------------------------------------------------

func test_reputation_accumulates_across_wins() -> void:
	_rep.award_match_win(_make_context())  # +5
	_rep.award_match_win(_make_context())  # +5
	assert_int(_rep.get_reputation()).is_equal(10)


# ---------------------------------------------------------------------------
# Tier lookup
# ---------------------------------------------------------------------------

func test_reputation_tier_unknown_at_zero() -> void:
	assert_str(_rep.get_reputation_tier()).is_equal("unknown")


func test_reputation_tier_boundaries() -> void:
	assert_str(_rep.get_tier_for_score(0)).is_equal("unknown")
	assert_str(_rep.get_tier_for_score(10)).is_equal("unknown")
	assert_str(_rep.get_tier_for_score(11)).is_equal("emerging")
	assert_str(_rep.get_tier_for_score(30)).is_equal("emerging")
	assert_str(_rep.get_tier_for_score(31)).is_equal("respected")
	assert_str(_rep.get_tier_for_score(55)).is_equal("respected")
	assert_str(_rep.get_tier_for_score(56)).is_equal("feared")
	assert_str(_rep.get_tier_for_score(79)).is_equal("feared")
	assert_str(_rep.get_tier_for_score(80)).is_equal("legendary")
	assert_str(_rep.get_tier_for_score(999)).is_equal("legendary")


# ---------------------------------------------------------------------------
# Chapter thresholds
# ---------------------------------------------------------------------------

func test_reputation_chapter_thresholds() -> void:
	assert_int(_rep.get_chapter_threshold(0)).is_equal(0)
	assert_int(_rep.get_chapter_threshold(1)).is_equal(0)
	assert_int(_rep.get_chapter_threshold(2)).is_equal(15)
	assert_int(_rep.get_chapter_threshold(3)).is_equal(35)
	assert_int(_rep.get_chapter_threshold(4)).is_equal(60)


func test_reputation_chapter_threshold_out_of_range_returns_zero() -> void:
	assert_int(_rep.get_chapter_threshold(99)).is_equal(0)


# ---------------------------------------------------------------------------
# Reset
# ---------------------------------------------------------------------------

func test_reputation_reset_clears_score_and_history() -> void:
	_rep.award_match_win(_make_context())
	assert_int(_rep.get_reputation()).is_greater(0)

	_rep.reset()
	assert_int(_rep.get_reputation()).is_equal(0)
	assert_dict(_rep.get_last_award()).is_empty()


# ---------------------------------------------------------------------------
# Save / Load round-trip
# ---------------------------------------------------------------------------

func test_reputation_save_load_round_trip() -> void:
	_rep.award_match_win(_make_context({"move_count": 10}))
	var saved: Dictionary = _rep.get_save_data()

	_rep.reset()
	assert_int(_rep.get_reputation()).is_equal(0)

	_rep.load_save_data(saved)
	assert_int(_rep.get_reputation()).is_equal(7)  # base(5) + speed(2)


# ---------------------------------------------------------------------------
# Signal emission
# ---------------------------------------------------------------------------

func test_reputation_changed_signal_emits() -> void:
	var signal_data := []
	_rep.reputation_changed.connect(func(total: int, earned: int, bd: Dictionary) -> void:
		signal_data.append({"total": total, "earned": earned, "breakdown": bd})
	)

	_rep.award_match_win(_make_context())

	assert_int(signal_data.size()).is_equal(1)
	assert_int(signal_data[0].total).is_equal(5)
	assert_int(signal_data[0].earned).is_equal(5)


# ---------------------------------------------------------------------------
# get_last_award
# ---------------------------------------------------------------------------

func test_reputation_get_last_award_returns_most_recent() -> void:
	_rep.award_match_win(_make_context({"opponent_id": "first"}))
	_rep.award_match_win(_make_context({"opponent_id": "second"}))

	var last: Dictionary = _rep.get_last_award()
	assert_str(last.opponent_id).is_equal("second")


# ---------------------------------------------------------------------------
# get_next_threshold
# ---------------------------------------------------------------------------

func test_reputation_get_next_threshold_at_zero() -> void:
	var next: Dictionary = _rep.get_next_threshold()
	assert_int(next.threshold).is_equal(15)
	assert_int(next.chapter).is_equal(2)
