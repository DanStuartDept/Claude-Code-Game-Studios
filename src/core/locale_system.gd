## Locale System — Loads and resolves translation keys for i18n.
##
## Loads locale JSON files from assets/data/locales/ and provides key-based
## string lookup with fallback to the provided default. Currently English-only;
## future locales add parallel JSON files (ga.json, fr.json, etc.).
##
## Architecture: Foundation Layer (ADR-0001). No gameplay dependencies.
## See: design/gdd/i18n.md (planned)
##
## Usage (Autoload — accessed globally):
##   var text: String = LocaleSystem.lookup("dialogue.seanan_pre_first", "fallback")
##   LocaleSystem.set_locale("ga")
extends Node


# --- Constants ---

const LOCALE_DIR: String = "res://assets/data/locales/"
const DEFAULT_LOCALE: String = "en"


# --- State ---

## Current locale code (e.g., "en", "ga").
var _current_locale: String = DEFAULT_LOCALE

## Loaded string table: { key: translated_string }.
var _strings: Dictionary = {}


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_load_locale(_current_locale)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Look up a translation key. Returns the translated string if found,
## or the fallback value if the key is missing or empty.
##
## Usage:
##   var text: String = LocaleSystem.lookup("dialogue.seanan_pre_first", line.text)
func lookup(key: String, fallback: String = "") -> String:
	if key == "":
		return fallback
	var value: String = _strings.get(key, "")
	if value == "":
		return fallback
	return value


## Get the current locale code.
##
## Usage:
##   var locale: String = LocaleSystem.get_locale()
func get_locale() -> String:
	return _current_locale


## Switch to a different locale. Reloads the string table.
##
## Usage:
##   LocaleSystem.set_locale("ga")
func set_locale(locale_code: String) -> void:
	if locale_code == _current_locale:
		return
	_current_locale = locale_code
	_load_locale(locale_code)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _load_locale(locale_code: String) -> void:
	var path: String = LOCALE_DIR + locale_code + ".json"
	if not FileAccess.file_exists(path):
		push_warning("LocaleSystem: Locale file not found at %s" % path)
		_strings = {}
		return

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var err: Error = json.parse(json_text)
	if err != OK:
		push_error("LocaleSystem: Failed to parse locale file: %s" % json.get_error_message())
		_strings = {}
		return

	_strings = json.data
