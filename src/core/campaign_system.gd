## Campaign System — Manages the 5-chapter journey through Fidchell.
##
## Tracks current chapter and match position, sequences opponents in order,
## gates chapter access via reputation thresholds, records match history,
## and drives scene flow between campaign map, dialogue, and match screens.
##
## Architecture: Feature Layer (ADR-0001). Depends on Board Rules, AI System,
## Scene Management, Reputation System, Dialogue System.
## See: design/gdd/campaign-system.md
##
## Usage (Autoload — accessed globally):
##   CampaignSystem.start_new_campaign()
##   CampaignSystem.get_current_match_entry()
##   CampaignSystem.start_current_match()
extends Node


# --- Signals ---

## Emitted when campaign state changes (chapter advanced, match completed, etc.).
signal campaign_state_changed()

## Emitted when a match result is processed (after reputation awarded).
signal match_result_processed(result: Dictionary)

## Emitted when a chapter is completed and the next chapter unlocks.
signal chapter_completed(chapter_index: int)

## Emitted when the entire campaign is completed.
signal campaign_completed()


# --- Campaign State Enum ---

enum CampaignState {
	INACTIVE,       ## No campaign loaded
	CAMPAIGN_MAP,   ## Viewing the campaign map, between matches
	PRE_DIALOGUE,   ## Pre-match dialogue playing
	MATCH_ACTIVE,   ## Board match in progress
	POST_DIALOGUE,  ## Post-match dialogue playing
	CHAPTER_TRANSITION, ## Transitioning between chapters
	CAMPAIGN_COMPLETE   ## Campaign finished
}


# --- Configuration ---

## Chapter definitions loaded from JSON: Array[Dictionary].
var _chapters: Array = []

## Match entries loaded from JSON: Array[Dictionary].
## Each: { match_id, chapter, order_in_chapter, opponent_path, match_type,
##          is_chapter_boss, is_final_boss }
var _matches: Array = []

## Path to campaign schedule JSON.
const SCHEDULE_PATH: String = "res://assets/data/campaign/campaign_schedule.json"


# --- Campaign State ---

## Current campaign state.
var state: int = CampaignState.INACTIVE

## Current chapter index (0 = Prologue).
var current_chapter: int = 0

## Current match index within the chapter (0-indexed).
var current_match_in_chapter: int = 0

## Whether the campaign has been started.
var campaign_active: bool = false

## Whether the campaign is completed.
var campaign_completed_flag: bool = false

## Whether the prologue has been completed.
var prologue_completed: bool = false


# --- Match History ---

## Per-opponent match history: { opponent_id: Array[Dictionary] }.
## Each entry: { result: "win"/"loss", move_count: int, pieces_remaining: int }
var match_history: Dictionary = {}

## Set of completed match IDs (for tracking which matches are done).
var completed_matches: Dictionary = {}

## Set of encountered opponent IDs (for Quick Play unlock).
var encountered_opponents: Dictionary = {}

## Number of consecutive losses to current opponent (for retry dialogue).
var current_loss_streak: int = 0


# --- Chapter Completion ---

## Set of defeated chapter boss IDs.
var defeated_bosses: Dictionary = {}


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_load_schedule()


# ---------------------------------------------------------------------------
# Schedule Queries
# ---------------------------------------------------------------------------

## Get all match entries for a given chapter.
func _get_chapter_matches(chapter_index: int) -> Array:
	var result: Array = []
	for entry: Dictionary in _matches:
		if entry.chapter == chapter_index:
			result.append(entry)
	# Sort by order_in_chapter
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.order_in_chapter < b.order_in_chapter)
	return result


## Get the chapter definition by index.
func _get_chapter_info(chapter_index: int) -> Dictionary:
	for ch: Dictionary in _chapters:
		if ch.get("index", -1) == chapter_index:
			return ch
	return {}


## Get total number of chapters.
func _get_chapter_count() -> int:
	return _chapters.size()


# ---------------------------------------------------------------------------
# Public API — Campaign Flow
# ---------------------------------------------------------------------------

## Start a new campaign from the Prologue.
##
## Usage:
##   CampaignSystem.start_new_campaign()
func start_new_campaign() -> void:
	current_chapter = 0
	current_match_in_chapter = 0
	campaign_active = true
	campaign_completed_flag = false
	prologue_completed = false
	match_history = {}
	completed_matches = {}
	encountered_opponents = {}
	defeated_bosses = {}
	current_loss_streak = 0
	state = CampaignState.CAMPAIGN_MAP
	campaign_state_changed.emit()


## Get the current match entry from the schedule.
##
## Usage:
##   var entry: Dictionary = CampaignSystem.get_current_match_entry()
func get_current_match_entry() -> Dictionary:
	var chapter_matches: Array = _get_chapter_matches(current_chapter)
	if current_match_in_chapter < chapter_matches.size():
		return chapter_matches[current_match_in_chapter]
	return {}


## Get the opponent profile for the current match.
##
## Usage:
##   var profile: OpponentProfile = CampaignSystem.get_current_opponent()
func get_current_opponent() -> Resource:
	var entry: Dictionary = get_current_match_entry()
	if entry.is_empty():
		return null

	var path: String = entry.get("opponent_path", "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null


## Get the current chapter definition.
##
## Usage:
##   var chapter: Dictionary = CampaignSystem.get_current_chapter_info()
func get_current_chapter_info() -> Dictionary:
	return _get_chapter_info(current_chapter)


## Get the total number of matches in the current chapter.
func get_chapter_match_count() -> int:
	return _get_chapter_matches(current_chapter).size()


## Check if the current chapter is complete (all matches won).
func is_chapter_complete() -> bool:
	var chapter_matches: Array = _get_chapter_matches(current_chapter)
	return current_match_in_chapter >= chapter_matches.size()


## Check if the next chapter is accessible (boss defeated + reputation threshold).
##
## Usage:
##   if CampaignSystem.can_advance_chapter():
func can_advance_chapter() -> bool:
	var next_chapter: int = current_chapter + 1
	if next_chapter >= _get_chapter_count():
		return false

	var next_info: Dictionary = _get_chapter_info(next_chapter)
	var rep_threshold: int = int(next_info.get("rep_threshold", 0))

	# Check reputation (via ReputationSystem autoload)
	var rep_system: Node = get_node_or_null("/root/ReputationSystem")
	var current_rep: int = 0
	if rep_system != null:
		current_rep = rep_system.get_reputation()

	# Must have beaten the current chapter's boss
	var chapter_matches: Array = _get_chapter_matches(current_chapter)
	var boss_defeated: bool = false
	for entry: Dictionary in chapter_matches:
		if entry.get("is_chapter_boss", false) and completed_matches.has(entry.match_id):
			boss_defeated = true
			break

	# Prologue has no boss gate — just complete both matches
	if current_chapter == 0:
		boss_defeated = is_chapter_complete()

	return boss_defeated and current_rep >= rep_threshold


## Advance to the next chapter.
##
## Usage:
##   CampaignSystem.advance_chapter()
func advance_chapter() -> void:
	if not can_advance_chapter():
		return

	var old_chapter: int = current_chapter
	current_chapter += 1
	current_match_in_chapter = 0
	current_loss_streak = 0

	if current_chapter == 1:
		prologue_completed = true

	if current_chapter >= _get_chapter_count():
		state = CampaignState.CAMPAIGN_COMPLETE
		campaign_completed_flag = true
		campaign_completed.emit()
	else:
		state = CampaignState.CAMPAIGN_MAP

	chapter_completed.emit(old_chapter)
	campaign_state_changed.emit()


## Process a match result (called after match ends).
##
## Usage:
##   CampaignSystem.process_match_result(result_dict)
func process_match_result(result: Dictionary) -> void:
	var entry: Dictionary = get_current_match_entry()
	if entry.is_empty():
		return

	var opponent: Resource = get_current_opponent()
	var opponent_id: String = ""
	if opponent != null:
		opponent_id = opponent.character_id

	var winner: int = result.get("winner", -1)
	var move_count: int = result.get("move_count", 0)
	var pieces_remaining: Dictionary = result.get("pieces_remaining", {})

	# Determine if player won (player is always DEFENDER = 1)
	var player_won: bool = (winner == 1)  # Side.DEFENDER

	# Record in match history
	var match_id: String = entry.get("match_id", "")
	var match_type: String = entry.get("match_type", "standard")
	var is_boss: bool = entry.get("is_chapter_boss", false)

	var record: Dictionary = {
		"result": "win" if player_won else "loss",
		"move_count": move_count,
		"defender_pieces": pieces_remaining.get("defender", 0),
		"match_id": match_id,
		"match_type": match_type,
		"is_chapter_boss": is_boss,
	}

	if not match_history.has(opponent_id):
		match_history[opponent_id] = []
	match_history[opponent_id].append(record)

	# Mark opponent as encountered
	encountered_opponents[opponent_id] = true

	if player_won:
		# Mark match completed
		completed_matches[match_id] = true
		current_loss_streak = 0

		# Track boss defeat
		if is_boss:
			defeated_bosses[opponent_id] = true

		# Award reputation (via ReputationSystem)
		_award_reputation(result, entry, opponent_id)

		# Advance to next match in chapter
		current_match_in_chapter += 1
	else:
		# Loss — stay at same position
		current_loss_streak += 1

	state = CampaignState.POST_DIALOGUE
	match_result_processed.emit(result)
	campaign_state_changed.emit()


## Get the encounter count for an opponent (how many times faced).
##
## Usage:
##   var count: int = CampaignSystem.get_encounter_count("seanán")
func get_encounter_count(opponent_id: String) -> int:
	if not match_history.has(opponent_id):
		return 0
	return match_history[opponent_id].size()


## Get the result history with an opponent for dialogue context.
## Returns: "no_prior", "lost_to_them", "beat_them", "mixed"
func get_result_history(opponent_id: String) -> String:
	if not match_history.has(opponent_id):
		return "no_prior"

	var records: Array = match_history[opponent_id]
	var wins: int = 0
	var losses: int = 0
	for record: Dictionary in records:
		if record.result == "win":
			wins += 1
		else:
			losses += 1

	if wins > 0 and losses > 0:
		return "mixed"
	elif wins > 0:
		return "beat_them"
	elif losses > 0:
		return "lost_to_them"
	return "no_prior"


## Get the encounter type string for dialogue.
## Returns: "first", "second", "third_plus"
func get_encounter_type(opponent_id: String) -> String:
	var count: int = get_encounter_count(opponent_id)
	if count == 0:
		return "first"
	elif count == 1:
		return "second"
	else:
		return "third_plus"


## Build dialogue context for the current match.
##
## Usage:
##   var ctx: Dictionary = CampaignSystem.build_dialogue_context("pre_match")
func build_dialogue_context(timing: String) -> Dictionary:
	var entry: Dictionary = get_current_match_entry()
	var opponent: Resource = get_current_opponent()
	if entry.is_empty():
		return {}

	var opponent_id: String = ""
	if opponent != null:
		opponent_id = opponent.character_id

	var rep_system: Node = get_node_or_null("/root/ReputationSystem")
	var rep_tier: String = "unknown"
	if rep_system != null and rep_system.has_method("get_reputation_tier"):
		rep_tier = rep_system.get_reputation_tier()

	return {
		"opponent_id": opponent_id,
		"timing": timing,
		"encounter": get_encounter_type(opponent_id),
		"result_history": get_result_history(opponent_id),
		"feud_state": "neutral",  # Feud System not yet implemented
		"reputation_tier": rep_tier,
		"is_chapter_boss": entry.get("is_chapter_boss", false),
		"is_final_boss": entry.get("is_final_boss", false),
		"match_type": entry.get("match_type", "standard"),
	}


## Check if the player has previously lost to a given opponent.
func has_lost_to(opponent_id: String) -> bool:
	if not match_history.has(opponent_id):
		return false
	for record: Dictionary in match_history[opponent_id]:
		if record.result == "loss":
			return true
	return false


## Get full campaign state for serialization (Save System).
##
## Usage:
##   var save_data: Dictionary = CampaignSystem.get_save_data()
func get_save_data() -> Dictionary:
	return {
		"current_chapter": current_chapter,
		"current_match_in_chapter": current_match_in_chapter,
		"campaign_active": campaign_active,
		"campaign_completed": campaign_completed_flag,
		"prologue_completed": prologue_completed,
		"match_history": match_history,
		"completed_matches": completed_matches,
		"encountered_opponents": encountered_opponents,
		"defeated_bosses": defeated_bosses,
	}


## Load campaign state from save data.
##
## Usage:
##   CampaignSystem.load_save_data(data)
func load_save_data(data: Dictionary) -> void:
	current_chapter = data.get("current_chapter", 0)
	current_match_in_chapter = data.get("current_match_in_chapter", 0)
	campaign_active = data.get("campaign_active", false)
	campaign_completed_flag = data.get("campaign_completed", false)
	prologue_completed = data.get("prologue_completed", false)
	match_history = data.get("match_history", {})
	completed_matches = data.get("completed_matches", {})
	encountered_opponents = data.get("encountered_opponents", {})
	defeated_bosses = data.get("defeated_bosses", {})
	state = CampaignState.CAMPAIGN_MAP
	current_loss_streak = 0
	campaign_state_changed.emit()


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _load_schedule() -> void:
	if not FileAccess.file_exists(SCHEDULE_PATH):
		push_warning("CampaignSystem: Schedule not found at %s" % SCHEDULE_PATH)
		return

	var file: FileAccess = FileAccess.open(SCHEDULE_PATH, FileAccess.READ)
	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var err: Error = json.parse(json_text)
	if err != OK:
		push_error("CampaignSystem: Failed to parse schedule JSON: %s" % json.get_error_message())
		return

	var data: Dictionary = json.data
	_chapters = data.get("chapters", [])

	# Parse match entries
	_matches = []
	for m: Dictionary in data.get("matches", []):
		_matches.append({
			"match_id": m.get("matchId", ""),
			"chapter": int(m.get("chapter", 0)),
			"order_in_chapter": int(m.get("orderInChapter", 0)),
			"opponent_path": m.get("opponentPath", ""),
			"match_type": m.get("matchType", "standard"),
			"is_chapter_boss": m.get("isChapterBoss", false),
			"is_final_boss": m.get("isFinalBoss", false),
		})


func _award_reputation(result: Dictionary, entry: Dictionary, opponent_id: String) -> void:
	var rep_system: Node = get_node_or_null("/root/ReputationSystem")
	if rep_system == null or not rep_system.has_method("award_match_win"):
		return

	var context: Dictionary = {
		"move_count": result.get("move_count", 0),
		"defender_pieces": result.get("pieces_remaining", {}).get("defender", 0),
		"is_chapter_boss": entry.get("is_chapter_boss", false),
		"is_feud_win": false,  # Feud System not yet implemented
		"is_nemesis_win": false,
		"is_rematch_win": has_lost_to(opponent_id),
		"opponent_id": opponent_id,
	}

	rep_system.award_match_win(context)
