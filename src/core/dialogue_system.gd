## Dialogue System — Context-aware line selection and display management.
##
## Selects dialogue lines from a tagged database using specificity-priority
## matching. Lines are keyed by opponent_id, timing, encounter, result_history,
## feud_state, reputation_tier, and match_type. The most specific match wins.
## Null tags in the database mean "match any."
##
## Architecture: Feature Layer (ADR-0001). Depends on Campaign System (context),
## Scene Management (overlay push/pop).
## See: design/gdd/dialogue-system.md
##
## Usage (Autoload — accessed globally):
##   DialogueSystem.show_dialogue(context)
##   await DialogueSystem.dialogue_complete
extends Node


# --- Signals ---

## Emitted when all dialogue lines have been dismissed by the player.
signal dialogue_complete()


# --- Configuration ---

## All dialogue lines loaded from JSON.
var _lines: Array = []

## Path to dialogue content JSON.
const DIALOGUE_PATH: String = "res://assets/data/campaign/dialogue_lines.json"

## Tag fields used for specificity matching, in priority order.
const TAG_FIELDS: Array = [
	"opponent_id", "timing", "match_type", "feud_state",
	"encounter", "result_history", "reputation_tier",
	"is_chapter_boss", "is_final_boss",
]


# --- State ---

## Lines selected for the current dialogue sequence.
var _current_lines: Array = []

## Current line index being displayed.
var _current_line_index: int = 0

## Whether dialogue is currently active.
var _active: bool = false


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_load_dialogue()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Select and return dialogue lines matching the given context.
## Does not display them — call show_dialogue() for that.
##
## Usage:
##   var lines: Array = DialogueSystem.select_lines(context)
func select_lines(context: Dictionary) -> Array:
	var candidates: Array = _find_matching_lines(context)
	if candidates.is_empty():
		return []

	# Sort by specificity (most specific first)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a._specificity > b._specificity)

	# Return the most specific match(es)
	# If multiple lines have the same top specificity, return all of them
	# (supports multi-line dialogue sequences)
	var top_specificity: int = candidates[0]._specificity
	var result: Array = []
	for candidate: Dictionary in candidates:
		if candidate._specificity == top_specificity:
			result.append(candidate)
		else:
			break

	return result


## Show dialogue for a given context. Selects lines, then emits
## dialogue_complete when the player dismisses all lines.
## Returns the selected lines (empty if none found).
##
## Usage:
##   DialogueSystem.show_dialogue(campaign_system.build_dialogue_context("pre_match"))
##   await DialogueSystem.dialogue_complete
func show_dialogue(context: Dictionary) -> Array:
	_current_lines = select_lines(context)
	if _current_lines.is_empty():
		# No dialogue — emit complete immediately
		dialogue_complete.emit()
		return []

	_current_line_index = 0
	_active = true
	return _current_lines


## Advance to the next line. Returns true if there are more lines,
## false if dialogue is complete.
##
## Usage:
##   var has_more: bool = DialogueSystem.advance()
func advance() -> bool:
	if not _active:
		return false

	_current_line_index += 1
	if _current_line_index >= _current_lines.size():
		_active = false
		_current_lines = []
		_current_line_index = 0
		dialogue_complete.emit()
		return false

	return true


## Get the current line being displayed.
func get_current_line() -> Dictionary:
	if _active and _current_line_index < _current_lines.size():
		return _current_lines[_current_line_index]
	return {}


## Whether dialogue is currently active.
func is_active() -> bool:
	return _active


## Cancel dialogue without completing it.
func cancel() -> void:
	_active = false
	_current_lines = []
	_current_line_index = 0


# ---------------------------------------------------------------------------
# Line Selection
# ---------------------------------------------------------------------------

## Find all lines that match the context (allowing null/missing tags as wildcards).
func _find_matching_lines(context: Dictionary) -> Array:
	var results: Array = []

	for line: Dictionary in _lines:
		var matches: bool = true
		var specificity: int = 0

		for tag: String in TAG_FIELDS:
			var line_value: Variant = line.get(tag)
			var context_value: Variant = context.get(tag)

			# Null/missing tag in line = wildcard (matches anything)
			if line_value == null or (line_value is String and line_value == ""):
				continue

			# Line has a specific value — context must match
			if context_value == null or (context_value is String and context_value == ""):
				matches = false
				break

			# Type-aware comparison (booleans may come as strings from JSON)
			if not _values_match(line_value, context_value):
				matches = false
				break

			# This tag matched specifically — increase specificity score
			specificity += 1

		if matches:
			var result: Dictionary = line.duplicate()
			result._specificity = specificity
			results.append(result)

	return results


## Compare two tag values, handling type differences from JSON.
## JSON booleans may arrive as strings ("true"/"false") while context
## passes native bools, so we normalize to strings for comparison.
func _values_match(line_val: Variant, context_val: Variant) -> bool:
	# Same type — direct comparison is safe
	if typeof(line_val) == typeof(context_val):
		return line_val == context_val

	# Different types — normalize to lowercase strings
	var line_str: String = str(line_val).to_lower()
	var ctx_str: String = str(context_val).to_lower()
	return line_str == ctx_str


# ---------------------------------------------------------------------------
# Data Loading
# ---------------------------------------------------------------------------

func _load_dialogue() -> void:
	if not FileAccess.file_exists(DIALOGUE_PATH):
		push_warning("DialogueSystem: Dialogue file not found at %s" % DIALOGUE_PATH)
		return

	var file: FileAccess = FileAccess.open(DIALOGUE_PATH, FileAccess.READ)
	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var err: Error = json.parse(json_text)
	if err != OK:
		push_error("DialogueSystem: Failed to parse dialogue JSON: %s" % json.get_error_message())
		return

	var data: Variant = json.data
	if data is Array:
		_lines = data
	elif data is Dictionary and data.has("lines"):
		_lines = data["lines"]
	else:
		push_error("DialogueSystem: Unexpected dialogue data format")
