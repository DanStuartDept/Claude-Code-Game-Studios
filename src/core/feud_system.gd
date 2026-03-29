## Feud System — Tracks personal rivalries between player and opponents.
##
## Per-opponent state machine: Neutral → Feud Pending → In Feud → Feud Resolved
## or Nemesis. Driven by match losses and feud tendency values. Provides feud
## state to Campaign (rematches), AI (difficulty override), Dialogue (state tag),
## and Reputation (bonus flags).
##
## Architecture: Feature Layer (ADR-0001). Depends on Campaign System (match results).
## See: design/gdd/feud-system.md
##
## Usage (Autoload — accessed globally):
##   FeudSystem.process_match_loss(opponent_id, feud_tendency, match_slot_id)
##   FeudSystem.get_feud_state(opponent_id) -> String
##   FeudSystem.get_active_feuds() -> Array
extends Node


# --- Signals ---

## Emitted when a feud state changes for any opponent.
signal feud_state_changed(opponent_id: String, old_state: String, new_state: String)


# --- Constants ---

## Feud state names (match the GDD exactly).
const STATE_NEUTRAL := "neutral"
const STATE_FEUD_PENDING := "feud_pending"
const STATE_IN_FEUD := "in_feud"
const STATE_FEUD_RESOLVED := "feud_resolved"
const STATE_NEMESIS := "nemesis"

## Terminal states — cannot be re-entered.
const TERMINAL_STATES: Array = ["feud_resolved"]


# --- Configuration ---

## Losses required to escalate from In Feud to Nemesis.
var nemesis_threshold: int = 3

## Difficulty bonus applied during feud/nemesis rematches.
var feud_difficulty_bonus: int = 1

## Maximum difficulty cap.
var max_difficulty: int = 7


# --- State ---

## Per-opponent feud data: { opponent_id: { state, encounter_loss_count, trigger_chapter } }
var _feud_data: Dictionary = {}


# ---------------------------------------------------------------------------
# Public API — Feud Queries
# ---------------------------------------------------------------------------

## Get the feud state for an opponent. Returns STATE_NEUTRAL if not tracked.
##
## Usage:
##   var state: String = FeudSystem.get_feud_state("tadhg")
func get_feud_state(opponent_id: String) -> String:
	if _feud_data.has(opponent_id):
		return _feud_data[opponent_id].get("state", STATE_NEUTRAL)
	return STATE_NEUTRAL


## Get the encounter loss count for an opponent.
func get_encounter_loss_count(opponent_id: String) -> int:
	if _feud_data.has(opponent_id):
		return int(_feud_data[opponent_id].get("encounter_loss_count", 0))
	return 0


## Get all opponents with active feuds (In Feud or Nemesis), sorted oldest first.
##
## Usage:
##   var feuds: Array = FeudSystem.get_active_feuds()
func get_active_feuds() -> Array:
	var active: Array = []
	for opp_id: String in _feud_data:
		var data: Dictionary = _feud_data[opp_id]
		var state: String = data.get("state", STATE_NEUTRAL)
		if state == STATE_IN_FEUD or state == STATE_NEMESIS:
			active.append({
				"opponent_id": opp_id,
				"state": state,
				"trigger_chapter": data.get("trigger_chapter", 0),
				"encounter_loss_count": data.get("encounter_loss_count", 0),
			})
	# Sort by trigger_chapter (oldest first)
	active.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.trigger_chapter < b.trigger_chapter)
	return active


## Get all opponents with pending feuds, sorted oldest first.
func get_pending_feuds() -> Array:
	var pending: Array = []
	for opp_id: String in _feud_data:
		var data: Dictionary = _feud_data[opp_id]
		if data.get("state", STATE_NEUTRAL) == STATE_FEUD_PENDING:
			pending.append({
				"opponent_id": opp_id,
				"trigger_chapter": data.get("trigger_chapter", 0),
			})
	pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.trigger_chapter < b.trigger_chapter)
	return pending


## Get the difficulty override for a feuding opponent.
## Returns the effective difficulty (base + bonus, capped at max).
##
## Usage:
##   var diff: int = FeudSystem.get_difficulty_override("tadhg", 2)
func get_difficulty_override(opponent_id: String, base_difficulty: int) -> int:
	var state: String = get_feud_state(opponent_id)
	if state == STATE_IN_FEUD or state == STATE_NEMESIS:
		return mini(base_difficulty + feud_difficulty_bonus, max_difficulty)
	return base_difficulty


## Check whether a win against this opponent should award feud bonus.
func is_feud_win(opponent_id: String) -> bool:
	var state: String = get_feud_state(opponent_id)
	return state == STATE_IN_FEUD or state == STATE_NEMESIS


## Check whether a win against this opponent should award nemesis bonus.
func is_nemesis_win(opponent_id: String) -> bool:
	return get_feud_state(opponent_id) == STATE_NEMESIS


# ---------------------------------------------------------------------------
# Public API — State Transitions
# ---------------------------------------------------------------------------

## Process a match loss and potentially trigger a feud.
## Called by CampaignSystem after a match result.
## feud_tendency: float 0.0-1.0 from opponent profile.
## current_chapter: int for tracking trigger timing.
##
## Usage:
##   FeudSystem.process_match_loss("tadhg", 0.8, 1)
func process_match_loss(opponent_id: String, feud_tendency: float, current_chapter: int) -> void:
	var state: String = get_feud_state(opponent_id)

	# Increment encounter loss count for In Feud / Nemesis
	if state == STATE_IN_FEUD:
		_feud_data[opponent_id].encounter_loss_count += 1
		# Check nemesis escalation
		if _feud_data[opponent_id].encounter_loss_count >= nemesis_threshold:
			_transition(opponent_id, STATE_NEMESIS)
		return

	if state == STATE_NEMESIS:
		_feud_data[opponent_id].encounter_loss_count += 1
		return

	# Only Neutral opponents can trigger new feuds
	if state != STATE_NEUTRAL:
		return

	# Check feud trigger conditions
	if feud_tendency <= 0.0:
		return

	if randf() < feud_tendency:
		_feud_data[opponent_id] = {
			"state": STATE_FEUD_PENDING,
			"encounter_loss_count": 1,
			"trigger_chapter": current_chapter,
		}
		feud_state_changed.emit(opponent_id, STATE_NEUTRAL, STATE_FEUD_PENDING)


## Activate a pending feud (called when Campaign fills a flex slot).
##
## Usage:
##   FeudSystem.activate_feud("tadhg")
func activate_feud(opponent_id: String) -> void:
	if get_feud_state(opponent_id) != STATE_FEUD_PENDING:
		return
	_transition(opponent_id, STATE_IN_FEUD)


## Process a feud/nemesis win (called when player wins a feud rematch).
##
## Usage:
##   FeudSystem.process_feud_win("tadhg")
func process_feud_win(opponent_id: String) -> void:
	var state: String = get_feud_state(opponent_id)
	if state == STATE_IN_FEUD or state == STATE_NEMESIS:
		_transition(opponent_id, STATE_FEUD_RESOLVED)


## Reset all feud state (for New Game).
func reset() -> void:
	_feud_data = {}


# ---------------------------------------------------------------------------
# Public API — Serialization
# ---------------------------------------------------------------------------

## Get all feud data for save serialization.
##
## Usage:
##   var data: Dictionary = FeudSystem.get_all_feud_data()
func get_all_feud_data() -> Dictionary:
	return _feud_data.duplicate(true)


## Load feud data from save.
##
## Usage:
##   FeudSystem.load_feud_data(save_data.feud)
func load_feud_data(data: Dictionary) -> void:
	_feud_data = data.duplicate(true) if data is Dictionary else {}


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _transition(opponent_id: String, new_state: String) -> void:
	var old_state: String = get_feud_state(opponent_id)

	if not _feud_data.has(opponent_id):
		_feud_data[opponent_id] = {
			"state": STATE_NEUTRAL,
			"encounter_loss_count": 0,
			"trigger_chapter": 0,
		}

	_feud_data[opponent_id].state = new_state
	feud_state_changed.emit(opponent_id, old_state, new_state)
