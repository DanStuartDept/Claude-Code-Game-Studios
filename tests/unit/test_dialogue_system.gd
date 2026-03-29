## GdUnit4 tests for Dialogue System
## Covers tag matching, specificity scoring, wildcard handling,
## type coercion (bool/string), advance/cancel flow, and edge cases.
##
## See: design/gdd/dialogue-system.md
class_name TestDialogueSystem
extends GdUnitTestSuite


const DialogueScript := preload("res://src/core/dialogue_system.gd")

var _ds: Node


func before_test() -> void:
	_ds = DialogueScript.new()
	add_child(_ds)
	# Inject test lines directly (bypass file loading)
	_ds._lines = _make_test_lines()


func after_test() -> void:
	_ds.queue_free()


# --- Test line database ---

func _make_test_lines() -> Array:
	return [
		# Line 0: Fully generic wildcard (matches anything)
		{
			"id": "generic_greeting",
			"text": "A match begins.",
			"timing": "pre_match",
		},
		# Line 1: Specific to seanan + pre_match
		{
			"id": "seanan_pre",
			"text": "The fisherman casts his net.",
			"opponent_id": "seanan",
			"timing": "pre_match",
		},
		# Line 2: Specific to seanan + pre_match + first encounter
		{
			"id": "seanan_first",
			"text": "First time meeting the fisherman.",
			"opponent_id": "seanan",
			"timing": "pre_match",
			"encounter": "first",
		},
		# Line 3: Specific to boss match
		{
			"id": "boss_pre",
			"text": "The boss awaits.",
			"timing": "pre_match",
			"is_chapter_boss": true,
		},
		# Line 4: Boolean field as string (JSON quirk)
		{
			"id": "final_boss_pre",
			"text": "The final battle.",
			"timing": "pre_match",
			"is_final_boss": "true",
		},
		# Line 5: Post-match line
		{
			"id": "generic_post",
			"text": "The match is over.",
			"timing": "post_match",
		},
		# Line 6: Feud state specific
		{
			"id": "feud_tadhg",
			"text": "Tadhg demands a rematch!",
			"opponent_id": "tadhg",
			"timing": "pre_match",
			"feud_state": "in_feud",
		},
		# Line 7: Same specificity as line 1 (opponent + timing) for multi-line test
		{
			"id": "seanan_pre_alt",
			"text": "The sea salt hangs in the air.",
			"opponent_id": "seanan",
			"timing": "pre_match",
		},
		# Line 8: Empty string tags treated as wildcard
		{
			"id": "empty_tags",
			"text": "Empty tag line.",
			"opponent_id": "",
			"timing": "pre_match",
			"encounter": "",
		},
	]


# ---------------------------------------------------------------------------
# Tag matching basics
# ---------------------------------------------------------------------------

func test_dialogue_select_generic_wildcard_matches() -> void:
	var context: Dictionary = {"timing": "pre_match", "opponent_id": "unknown"}
	var lines: Array = _ds.select_lines(context)
	assert_bool(lines.size() > 0).is_true()


func test_dialogue_select_specific_opponent_beats_generic() -> void:
	var context: Dictionary = {"timing": "pre_match", "opponent_id": "seanan"}
	var lines: Array = _ds.select_lines(context)
	# Most specific: seanan + pre_match (specificity 2), not generic (specificity 1)
	assert_bool(lines.size() > 0).is_true()
	# All top lines should have opponent_id = seanan
	for line: Dictionary in lines:
		assert_str(line.opponent_id).is_equal("seanan")


# ---------------------------------------------------------------------------
# Specificity scoring
# ---------------------------------------------------------------------------

func test_dialogue_most_specific_match_wins() -> void:
	var context: Dictionary = {
		"timing": "pre_match",
		"opponent_id": "seanan",
		"encounter": "first",
	}
	var lines: Array = _ds.select_lines(context)
	# seanan_first has 3 specific tags; seanan_pre has 2
	assert_int(lines.size()).is_equal(1)
	assert_str(lines[0].id).is_equal("seanan_first")


func test_dialogue_multi_line_same_specificity_returned() -> void:
	var context: Dictionary = {
		"timing": "pre_match",
		"opponent_id": "seanan",
		"encounter": "second",  # No specific match for "second" encounter
	}
	var lines: Array = _ds.select_lines(context)
	# seanan_pre and seanan_pre_alt both have specificity 2
	assert_int(lines.size()).is_equal(2)
	var ids: Array = []
	for line: Dictionary in lines:
		ids.append(line.id)
	assert_bool("seanan_pre" in ids).is_true()
	assert_bool("seanan_pre_alt" in ids).is_true()


# ---------------------------------------------------------------------------
# Wildcard handling (null/empty tags)
# ---------------------------------------------------------------------------

func test_dialogue_null_tag_in_line_matches_anything() -> void:
	# generic_greeting has only "timing" — no opponent_id, so it matches any opponent
	var context: Dictionary = {"timing": "pre_match", "opponent_id": "brigid"}
	var lines: Array = _ds.select_lines(context)
	var ids: Array = []
	for line: Dictionary in lines:
		ids.append(line.id)
	# generic_greeting should be in candidates (though not top specificity for brigid)
	# At specificity 1 (timing only), generic_greeting and empty_tags match
	assert_bool(lines.size() > 0).is_true()


func test_dialogue_empty_string_tag_treated_as_wildcard() -> void:
	# Line 8 has empty string tags — should match like null
	var context: Dictionary = {"timing": "pre_match", "opponent_id": "brigid"}
	var all_candidates: Array = _ds._find_matching_lines(context)
	var has_empty_tags: bool = false
	for c: Dictionary in all_candidates:
		if c.id == "empty_tags":
			has_empty_tags = true
			break
	assert_bool(has_empty_tags).is_true()


# ---------------------------------------------------------------------------
# Type coercion (bool/string comparison)
# ---------------------------------------------------------------------------

func test_dialogue_bool_context_matches_string_line() -> void:
	# Line 4 has is_final_boss: "true" (string), context passes bool true
	var context: Dictionary = {
		"timing": "pre_match",
		"is_final_boss": true,
	}
	var all_candidates: Array = _ds._find_matching_lines(context)
	var has_final: bool = false
	for c: Dictionary in all_candidates:
		if c.id == "final_boss_pre":
			has_final = true
			break
	assert_bool(has_final).is_true()


func test_dialogue_bool_line_matches_bool_context() -> void:
	# Line 3 has is_chapter_boss: true (bool)
	var context: Dictionary = {
		"timing": "pre_match",
		"is_chapter_boss": true,
	}
	var all_candidates: Array = _ds._find_matching_lines(context)
	var has_boss: bool = false
	for c: Dictionary in all_candidates:
		if c.id == "boss_pre":
			has_boss = true
			break
	assert_bool(has_boss).is_true()


func test_dialogue_false_bool_does_not_match_true() -> void:
	# is_chapter_boss: false should NOT match line 3 (is_chapter_boss: true)
	var context: Dictionary = {
		"timing": "pre_match",
		"is_chapter_boss": false,
	}
	var all_candidates: Array = _ds._find_matching_lines(context)
	var has_boss: bool = false
	for c: Dictionary in all_candidates:
		if c.id == "boss_pre":
			has_boss = true
			break
	assert_bool(has_boss).is_false()


# ---------------------------------------------------------------------------
# Timing filter
# ---------------------------------------------------------------------------

func test_dialogue_timing_filter_separates_pre_and_post() -> void:
	var pre_lines: Array = _ds.select_lines({"timing": "pre_match"})
	var post_lines: Array = _ds.select_lines({"timing": "post_match"})

	for line: Dictionary in pre_lines:
		if line.has("timing"):
			assert_str(str(line.timing)).is_not_equal("post_match")

	for line: Dictionary in post_lines:
		assert_str(line.id).is_equal("generic_post")


# ---------------------------------------------------------------------------
# Feud state matching
# ---------------------------------------------------------------------------

func test_dialogue_feud_state_specific_line_selected() -> void:
	var context: Dictionary = {
		"timing": "pre_match",
		"opponent_id": "tadhg",
		"feud_state": "in_feud",
	}
	var lines: Array = _ds.select_lines(context)
	assert_int(lines.size()).is_equal(1)
	assert_str(lines[0].id).is_equal("feud_tadhg")


func test_dialogue_neutral_feud_does_not_match_in_feud_line() -> void:
	var context: Dictionary = {
		"timing": "pre_match",
		"opponent_id": "tadhg",
		"feud_state": "neutral",
	}
	var all_candidates: Array = _ds._find_matching_lines(context)
	var has_feud_line: bool = false
	for c: Dictionary in all_candidates:
		if c.id == "feud_tadhg":
			has_feud_line = true
			break
	assert_bool(has_feud_line).is_false()


# ---------------------------------------------------------------------------
# Advance / cancel flow
# ---------------------------------------------------------------------------

func test_dialogue_advance_through_all_lines() -> void:
	var context: Dictionary = {
		"timing": "pre_match",
		"opponent_id": "seanan",
		"encounter": "second",
	}
	_ds.show_dialogue(context)
	assert_bool(_ds.is_active()).is_true()

	# Line index 0 -> advance to 1
	var more: bool = _ds.advance()
	assert_bool(more).is_true()

	# Line index 1 -> advance to 2 (past end)
	more = _ds.advance()
	assert_bool(more).is_false()
	assert_bool(_ds.is_active()).is_false()


func test_dialogue_cancel_stops_immediately() -> void:
	_ds.show_dialogue({"timing": "pre_match", "opponent_id": "seanan", "encounter": "second"})
	assert_bool(_ds.is_active()).is_true()

	_ds.cancel()
	assert_bool(_ds.is_active()).is_false()
	assert_dict(_ds.get_current_line()).is_empty()


func test_dialogue_complete_signal_emits() -> void:
	var signal_count: Array = [0]
	_ds.dialogue_complete.connect(func() -> void: signal_count[0] += 1)

	_ds.show_dialogue({"timing": "pre_match", "opponent_id": "seanan", "encounter": "first"})
	# Single line — one advance completes
	_ds.advance()

	assert_int(signal_count[0]).is_equal(1)


func test_dialogue_no_lines_emits_complete_immediately() -> void:
	var signal_count: Array = [0]
	_ds.dialogue_complete.connect(func() -> void: signal_count[0] += 1)

	_ds.show_dialogue({"timing": "nonexistent_timing"})
	assert_int(signal_count[0]).is_equal(1)
	assert_bool(_ds.is_active()).is_false()


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

func test_dialogue_empty_context_returns_no_specific_lines() -> void:
	# Empty context — lines with specific tags should NOT match
	# (a line requires timing: "pre_match" but context has no timing)
	var lines: Array = _ds.select_lines({})
	# All test lines have at least a timing tag, so none match empty context
	assert_int(lines.size()).is_equal(0)


func test_dialogue_advance_when_inactive_returns_false() -> void:
	assert_bool(_ds.advance()).is_false()
