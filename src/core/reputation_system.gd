## Reputation System — Tracks the player's standing throughout the campaign.
##
## A single accumulating score that increases on match wins with stacking
## bonuses (speed, decisive, boss, feud, nemesis, rematch). Never decreases.
## Gates chapter access via thresholds and influences dialogue tone via tiers.
##
## Architecture: Feature Layer (ADR-0001). Depends on Campaign System (provides
## match results). Consumed by Dialogue System (tier lookup), Campaign UI.
## See: design/gdd/reputation-system.md
##
## Usage (Autoload — accessed globally):
##   ReputationSystem.award_match_win(context)
##   ReputationSystem.get_reputation()
##   ReputationSystem.get_reputation_tier()
extends Node


# --- Signals ---

## Emitted when reputation changes. Includes breakdown of what was earned.
signal reputation_changed(new_total: int, earned: int, breakdown: Dictionary)


# --- Config ---

var _base_win: int = 5
var _speed_bonus: int = 2
var _speed_threshold_moves: int = 20
var _decisive_bonus: int = 1
var _decisive_threshold_pieces: int = 5
var _feud_bonus: int = 3
var _nemesis_bonus: int = 5
var _boss_bonus: int = 3
var _rematch_bonus: int = 1
var _chapter_thresholds: Array = [0, 0, 15, 35, 60]
var _final_boss_threshold: int = 80
var _tier_ranges: Dictionary = {}

const CONFIG_PATH: String = "res://assets/data/campaign/reputation_config.json"


# --- State ---

## Current reputation score.
var _reputation: int = 0

## History of reputation awards for post-match display.
var _history: Array = []


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_load_config()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Get the current reputation score.
##
## Usage:
##   var rep: int = ReputationSystem.get_reputation()
func get_reputation() -> int:
	return _reputation


## Get the reputation tier name for the current score.
## Returns: "unknown", "emerging", "respected", "feared", "legendary"
##
## Usage:
##   var tier: String = ReputationSystem.get_reputation_tier()
func get_reputation_tier() -> String:
	return get_tier_for_score(_reputation)


## Get the tier name for a given score.
func get_tier_for_score(score: int) -> String:
	for tier_name: String in ["legendary", "feared", "respected", "emerging", "unknown"]:
		if _tier_ranges.has(tier_name):
			var range_arr: Array = _tier_ranges[tier_name]
			if score >= int(range_arr[0]) and score <= int(range_arr[1]):
				return tier_name
	return "unknown"


## Get the reputation threshold for a chapter.
##
## Usage:
##   var threshold: int = ReputationSystem.get_chapter_threshold(2)
func get_chapter_threshold(chapter_index: int) -> int:
	if chapter_index >= 0 and chapter_index < _chapter_thresholds.size():
		return int(_chapter_thresholds[chapter_index])
	return 0


## Get the next reputation threshold above the current score.
## Returns { threshold: int, chapter: int } or empty dict if at max.
func get_next_threshold() -> Dictionary:
	for i: int in _chapter_thresholds.size():
		var threshold: int = int(_chapter_thresholds[i])
		if threshold > _reputation:
			return { "threshold": threshold, "chapter": i }
	if _reputation < _final_boss_threshold:
		return { "threshold": _final_boss_threshold, "chapter": -1 }
	return {}


## Award reputation for a match win.
## Called by CampaignSystem after processing a match result.
##
## Context keys:
##   move_count: int, defender_pieces: int, is_chapter_boss: bool,
##   is_feud_win: bool, is_nemesis_win: bool, is_rematch_win: bool
##
## Usage:
##   ReputationSystem.award_match_win({ "move_count": 18, ... })
func award_match_win(context: Dictionary) -> Dictionary:
	var earned: int = _base_win
	var breakdown: Dictionary = { "base": _base_win }

	# Speed bonus
	var move_count: int = context.get("move_count", 999)
	if move_count <= _speed_threshold_moves:
		earned += _speed_bonus
		breakdown["speed"] = _speed_bonus

	# Decisive bonus
	var defender_pieces: int = context.get("defender_pieces", 0)
	if defender_pieces >= _decisive_threshold_pieces:
		earned += _decisive_bonus
		breakdown["decisive"] = _decisive_bonus

	# Boss bonus
	if context.get("is_chapter_boss", false):
		earned += _boss_bonus
		breakdown["boss"] = _boss_bonus

	# Feud bonus
	if context.get("is_feud_win", false):
		earned += _feud_bonus
		breakdown["feud"] = _feud_bonus

	# Nemesis bonus
	if context.get("is_nemesis_win", false):
		earned += _nemesis_bonus
		breakdown["nemesis"] = _nemesis_bonus

	# Rematch bonus (beat someone who beat you)
	if context.get("is_rematch_win", false):
		earned += _rematch_bonus
		breakdown["rematch"] = _rematch_bonus

	_reputation += earned

	var record: Dictionary = {
		"opponent_id": context.get("opponent_id", ""),
		"earned": earned,
		"breakdown": breakdown,
		"total_after": _reputation,
	}
	_history.append(record)

	reputation_changed.emit(_reputation, earned, breakdown)
	return breakdown


## Get the most recent reputation award (for post-match display).
func get_last_award() -> Dictionary:
	if _history.size() > 0:
		return _history[_history.size() - 1]
	return {}


## Reset reputation (for new campaign).
func reset() -> void:
	_reputation = 0
	_history = []


## Get full state for serialization.
func get_save_data() -> Dictionary:
	return {
		"reputation": _reputation,
		"history": _history,
	}


## Load state from save data.
func load_save_data(data: Dictionary) -> void:
	_reputation = data.get("reputation", 0)
	_history = data.get("history", [])


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("ReputationSystem: Config not found at %s, using defaults" % CONFIG_PATH)
		_set_default_tiers()
		return

	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var err: Error = json.parse(json_text)
	if err != OK:
		push_error("ReputationSystem: Failed to parse config: %s" % json.get_error_message())
		_set_default_tiers()
		return

	var data: Dictionary = json.data
	_base_win = int(data.get("baseWin", 5))
	_speed_bonus = int(data.get("speedBonus", 2))
	_speed_threshold_moves = int(data.get("speedThresholdMoves", 20))
	_decisive_bonus = int(data.get("decisiveBonus", 1))
	_decisive_threshold_pieces = int(data.get("decisiveThresholdPieces", 5))
	_feud_bonus = int(data.get("feudBonus", 3))
	_nemesis_bonus = int(data.get("nemesisBonus", 5))
	_boss_bonus = int(data.get("bossBonus", 3))
	_rematch_bonus = int(data.get("rematchBonus", 1))
	_chapter_thresholds = data.get("chapterThresholds", [0, 0, 15, 35, 60])
	_final_boss_threshold = int(data.get("finalBossThreshold", 80))
	_tier_ranges = data.get("tierRanges", {})

	if _tier_ranges.is_empty():
		_set_default_tiers()


func _set_default_tiers() -> void:
	_tier_ranges = {
		"unknown": [0, 10],
		"emerging": [11, 30],
		"respected": [31, 55],
		"feared": [56, 79],
		"legendary": [80, 9999],
	}
