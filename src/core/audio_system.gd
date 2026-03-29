## Audio System — Manages music, SFX, and ambient audio.
##
## Signal-driven: listens to BoardRules, SceneManager, and CampaignSystem signals.
## Three independent buses (Music, SFX, Ambient) with per-bus volume control.
## Supports crossfading, ducking during overlays, and sequential capture SFX.
## All mappings loaded from external config — no hardcoded audio paths.
##
## Architecture: Feature Layer (ADR-0001). Depends on SceneManager, BoardRules.
## See: design/gdd/audio-system.md
##
## Usage (Autoload — accessed globally):
##   AudioSystem.play_sfx("piece_moved")
##   AudioSystem.play_music("main_menu")
##   AudioSystem.set_bus_volume("music", 0.5)
extends Node


# --- Signals ---

## Emitted when a music track starts playing.
signal music_started(track_id: String)

## Emitted when a music crossfade completes.
signal music_crossfade_completed()

## Emitted when music is ducked or unducked.
signal music_ducked(is_ducked: bool)


# --- Constants ---

const CONFIG_PATH: String = "res://assets/data/audio/audio_config.json"

## Bus name constants matching Godot AudioServer bus layout.
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_AMBIENT: StringName = &"Ambient"
const BUS_MASTER: StringName = &"Master"


# --- Config (loaded from JSON) ---

var _config: Dictionary = {}
var _sfx_events: Dictionary = {}
var _music_tracks: Dictionary = {}
var _ambient_tracks: Dictionary = {}
var _sting_volumes: Dictionary = {}


# --- Tuning Knobs (from config, with defaults) ---

var _crossfade_duration: float = 1.0
var _duck_amount: float = 0.2
var _duck_fade_duration: float = 0.3
var _sfx_capture_gap: float = 0.1


# --- Audio Players ---

## Two music players for crossfading.
var _music_player_a: AudioStreamPlayer = null
var _music_player_b: AudioStreamPlayer = null

## Which player is currently active (true = A, false = B).
var _music_active_is_a: bool = true

## Ambient audio player.
var _ambient_player: AudioStreamPlayer = null

## Pool of SFX players for concurrent sounds.
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 8


# --- State ---

## Currently playing music track ID (from config key).
var _current_music_id: String = ""

## Currently playing ambient track ID.
var _current_ambient_id: String = ""

## Whether music is currently ducked (overlay active).
var _is_ducked: bool = false

## Pre-duck music volume for restoration.
var _pre_duck_volume_db: float = 0.0

## Whether a crossfade is in progress.
var _crossfading: bool = false

## Pending sequential capture SFX count.
var _pending_captures: int = 0

## User volume settings (linear 0.0–1.0) per bus.
var _bus_volumes: Dictionary = {
	"music": 0.7,
	"sfx": 1.0,
	"ambient": 0.5,
}

## Cache of loaded audio streams to avoid redundant disk reads.
var _stream_cache: Dictionary = {}


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_load_config()
	_ensure_buses_exist()
	_create_audio_players()
	_apply_default_volumes()
	call_deferred("_connect_signals")


# ---------------------------------------------------------------------------
# Public API — Volume Control
# ---------------------------------------------------------------------------

## Set volume for a bus. Linear scale 0.0–1.0.
##
## Usage:
##   AudioSystem.set_bus_volume("music", 0.5)
func set_bus_volume(bus_name: String, volume_linear: float) -> void:
	volume_linear = clampf(volume_linear, 0.0, 1.0)
	_bus_volumes[bus_name] = volume_linear

	var bus_idx: int = AudioServer.get_bus_index(_bus_name_to_godot(bus_name))
	if bus_idx < 0:
		return
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(volume_linear))


## Get the current volume for a bus (linear 0.0–1.0).
##
## Usage:
##   var vol: float = AudioSystem.get_bus_volume("music")
func get_bus_volume(bus_name: String) -> float:
	return _bus_volumes.get(bus_name, 1.0)


## Get all bus volumes as a dictionary (for save system).
##
## Usage:
##   var volumes: Dictionary = AudioSystem.get_all_volumes()
func get_all_volumes() -> Dictionary:
	return _bus_volumes.duplicate()


## Restore bus volumes from a saved dictionary.
##
## Usage:
##   AudioSystem.restore_volumes(saved_data.audio_volumes)
func restore_volumes(volumes: Dictionary) -> void:
	for bus_name: String in volumes:
		set_bus_volume(bus_name, float(volumes[bus_name]))


# ---------------------------------------------------------------------------
# Public API — SFX
# ---------------------------------------------------------------------------

## Play a sound effect by event ID (from audio_config.json sfxEvents).
## Returns true if the sound was found and played.
##
## Usage:
##   AudioSystem.play_sfx("piece_moved")
func play_sfx(event_id: String) -> bool:
	if not _sfx_events.has(event_id):
		push_warning("AudioSystem: No SFX mapping for event '%s'" % event_id)
		return false

	var path: String = _sfx_events[event_id]
	var stream: AudioStream = _load_stream(path)
	if stream == null:
		return false

	var player: AudioStreamPlayer = _get_available_sfx_player()
	if player == null:
		return false

	player.stream = stream
	player.bus = BUS_SFX

	# Apply sting volume override if configured
	if _sting_volumes.has(event_id):
		player.volume_db = linear_to_db(float(_sting_volumes[event_id]))
	else:
		player.volume_db = 0.0

	player.play()
	return true


# ---------------------------------------------------------------------------
# Public API — Music
# ---------------------------------------------------------------------------

## Play a music track by ID (from audio_config.json musicTracks).
## Crossfades from the current track if one is playing.
##
## Usage:
##   AudioSystem.play_music("main_menu")
func play_music(track_id: String) -> void:
	if track_id == _current_music_id:
		return

	if not _music_tracks.has(track_id):
		push_warning("AudioSystem: No music mapping for track '%s'" % track_id)
		return

	var path: String = _music_tracks[track_id]
	var stream: AudioStream = _load_stream(path)
	if stream == null:
		return

	_current_music_id = track_id

	var incoming: AudioStreamPlayer = _get_incoming_music_player()
	incoming.stream = stream
	incoming.bus = BUS_MUSIC
	incoming.volume_db = linear_to_db(0.0)
	incoming.play()

	_crossfade_music(incoming)


## Stop music with a fade-out.
##
## Usage:
##   AudioSystem.stop_music()
func stop_music() -> void:
	_current_music_id = ""
	var active: AudioStreamPlayer = _get_active_music_player()
	if active.playing:
		var tween: Tween = create_tween()
		tween.tween_property(active, "volume_db", linear_to_db(0.0), _crossfade_duration)
		tween.tween_callback(active.stop)


# ---------------------------------------------------------------------------
# Public API — Ambient
# ---------------------------------------------------------------------------

## Play an ambient track by chapter index. Crossfades from current ambient.
##
## Usage:
##   AudioSystem.play_ambient_for_chapter(2)
func play_ambient_for_chapter(chapter_index: int) -> void:
	var track_id: String = "chapter_%d" % chapter_index
	if track_id == _current_ambient_id:
		return

	if not _ambient_tracks.has(track_id):
		push_warning("AudioSystem: No ambient mapping for '%s'" % track_id)
		return

	var path: String = _ambient_tracks[track_id]
	var stream: AudioStream = _load_stream(path)
	if stream == null:
		return

	_current_ambient_id = track_id

	# Crossfade ambient
	var tween: Tween = create_tween()
	if _ambient_player.playing:
		tween.tween_property(_ambient_player, "volume_db", linear_to_db(0.0), _crossfade_duration)
		tween.tween_callback(_ambient_player.stop)
		tween.tween_callback(func() -> void:
			_ambient_player.stream = stream
			_ambient_player.volume_db = linear_to_db(0.0)
			_ambient_player.play()
		)
		tween.tween_property(
			_ambient_player, "volume_db",
			linear_to_db(_bus_volumes.get("ambient", 0.5)),
			_crossfade_duration
		)
	else:
		_ambient_player.stream = stream
		_ambient_player.bus = BUS_AMBIENT
		_ambient_player.volume_db = linear_to_db(0.0)
		_ambient_player.play()
		tween.tween_property(
			_ambient_player, "volume_db",
			linear_to_db(_bus_volumes.get("ambient", 0.5)),
			_crossfade_duration
		)


## Stop ambient audio with fade-out.
##
## Usage:
##   AudioSystem.stop_ambient()
func stop_ambient() -> void:
	_current_ambient_id = ""
	if _ambient_player.playing:
		var tween: Tween = create_tween()
		tween.tween_property(_ambient_player, "volume_db", linear_to_db(0.0), _crossfade_duration)
		tween.tween_callback(_ambient_player.stop)


# ---------------------------------------------------------------------------
# Public API — Ducking
# ---------------------------------------------------------------------------

## Duck music volume (e.g., during dialogue overlay).
##
## Usage:
##   AudioSystem.duck_music()
func duck_music() -> void:
	if _is_ducked:
		return
	_is_ducked = true

	var bus_idx: int = AudioServer.get_bus_index(BUS_MUSIC)
	if bus_idx < 0:
		return

	_pre_duck_volume_db = AudioServer.get_bus_volume_db(bus_idx)
	var ducked_db: float = linear_to_db(
		db_to_linear(_pre_duck_volume_db) * (1.0 - _duck_amount)
	)

	var tween: Tween = create_tween()
	tween.tween_method(
		func(db: float) -> void: AudioServer.set_bus_volume_db(bus_idx, db),
		_pre_duck_volume_db,
		ducked_db,
		_duck_fade_duration
	)
	music_ducked.emit(true)


## Restore music volume after ducking.
##
## Usage:
##   AudioSystem.unduck_music()
func unduck_music() -> void:
	if not _is_ducked:
		return
	_is_ducked = false

	var bus_idx: int = AudioServer.get_bus_index(BUS_MUSIC)
	if bus_idx < 0:
		return

	var current_db: float = AudioServer.get_bus_volume_db(bus_idx)
	var tween: Tween = create_tween()
	tween.tween_method(
		func(db: float) -> void: AudioServer.set_bus_volume_db(bus_idx, db),
		current_db,
		_pre_duck_volume_db,
		_duck_fade_duration
	)
	music_ducked.emit(false)


# ---------------------------------------------------------------------------
# Public API — State queries
# ---------------------------------------------------------------------------

## Get the currently playing music track ID.
##
## Usage:
##   var track: String = AudioSystem.get_current_music_id()
func get_current_music_id() -> String:
	return _current_music_id


## Get the currently playing ambient track ID.
##
## Usage:
##   var ambient: String = AudioSystem.get_current_ambient_id()
func get_current_ambient_id() -> String:
	return _current_ambient_id


## Whether music is currently ducked.
##
## Usage:
##   if AudioSystem.is_music_ducked():
func is_music_ducked() -> bool:
	return _is_ducked


# ---------------------------------------------------------------------------
# Public API — Board UI wiring
# ---------------------------------------------------------------------------

## Connect to a BoardUI instance for piece select/deselect SFX.
## Call this when a match scene creates its BoardUI.
##
## Usage:
##   AudioSystem.connect_board_ui(board_ui_node)
func connect_board_ui(board_ui: Node) -> void:
	if board_ui.has_signal("piece_selected"):
		board_ui.piece_selected.connect(_on_piece_selected)
	if board_ui.has_signal("piece_deselected"):
		board_ui.piece_deselected.connect(_on_piece_deselected)


# ---------------------------------------------------------------------------
# Signal handlers — Board Rules Engine
# ---------------------------------------------------------------------------

func _on_piece_moved(_piece_type: int, _from: Vector2i, _to: Vector2i) -> void:
	play_sfx("piece_moved")


func _on_piece_captured(_piece_type: int, _position: Vector2i, _captured_by: Vector2i) -> void:
	# Queue sequential captures with gap
	_pending_captures += 1
	if _pending_captures == 1:
		_play_capture_sequence()


func _on_king_threatened(_king_pos: Vector2i, _threat_count: int) -> void:
	play_sfx("king_threatened")


func _on_turn_changed(_new_active_side: int) -> void:
	play_sfx("turn_changed")


func _on_match_ended(result: Dictionary) -> void:
	# Fade match music, play victory or defeat sting
	stop_music()
	var is_victory: bool = result.get("winner", "") == "player"
	if is_victory:
		play_sfx("match_victory")
	else:
		play_sfx("match_defeat")


# ---------------------------------------------------------------------------
# Signal handlers — Board UI
# ---------------------------------------------------------------------------

func _on_piece_selected(_cell: Vector2i) -> void:
	play_sfx("piece_selected")


func _on_piece_deselected() -> void:
	play_sfx("piece_deselected")


# ---------------------------------------------------------------------------
# Signal handlers — Scene Manager
# ---------------------------------------------------------------------------

func _on_scene_changed(_old_key: StringName, new_key: StringName) -> void:
	# Map scene keys to music tracks
	var track_id: String = _scene_to_music_track(new_key)
	if not track_id.is_empty():
		play_music(track_id)


func _on_overlay_pushed(_overlay_key: StringName) -> void:
	duck_music()


func _on_overlay_popped(_overlay_key: StringName) -> void:
	unduck_music()


func _on_app_paused() -> void:
	_pause_all_audio()


func _on_app_resumed() -> void:
	_resume_all_audio()


# ---------------------------------------------------------------------------
# Internal — Config loading
# ---------------------------------------------------------------------------

func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("AudioSystem: Config not found at %s, using defaults" % CONFIG_PATH)
		return

	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_warning("AudioSystem: Failed to open config at %s" % CONFIG_PATH)
		return

	var json := JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_error("AudioSystem: Invalid config JSON: %s" % json.get_error_message())
		return

	_config = json.data as Dictionary

	# Extract sub-dictionaries
	_sfx_events = _config.get("sfxEvents", {})
	_music_tracks = _config.get("musicTracks", {})
	_ambient_tracks = _config.get("ambientTracks", {})
	_sting_volumes = _config.get("stingVolumes", {})

	# Extract tuning knobs
	_crossfade_duration = float(_config.get("crossfadeDuration", 1.0))
	_duck_amount = float(_config.get("duckAmount", 0.2))
	_duck_fade_duration = float(_config.get("duckFadeDuration", 0.3))
	_sfx_capture_gap = float(_config.get("sfxCaptureGap", 0.1))

	# Extract default volumes
	var buses: Dictionary = _config.get("buses", {})
	for bus_name: String in buses:
		var bus_data: Dictionary = buses[bus_name]
		if bus_data.has("defaultVolume"):
			_bus_volumes[bus_name] = float(bus_data.defaultVolume)


# ---------------------------------------------------------------------------
# Internal — Bus setup
# ---------------------------------------------------------------------------

func _ensure_buses_exist() -> void:
	# Create buses if they don't exist (in editor/test they may already exist)
	for bus_name: StringName in [BUS_MUSIC, BUS_SFX, BUS_AMBIENT]:
		if AudioServer.get_bus_index(bus_name) < 0:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, BUS_MASTER)


func _apply_default_volumes() -> void:
	for bus_name: String in _bus_volumes:
		set_bus_volume(bus_name, _bus_volumes[bus_name])


# ---------------------------------------------------------------------------
# Internal — Player creation
# ---------------------------------------------------------------------------

func _create_audio_players() -> void:
	# Two music players for crossfading
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = BUS_MUSIC
	_music_player_a.name = "MusicPlayerA"
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = BUS_MUSIC
	_music_player_b.name = "MusicPlayerB"
	add_child(_music_player_b)

	# Ambient player
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = BUS_AMBIENT
	_ambient_player.name = "AmbientPlayer"
	add_child(_ambient_player)

	# SFX pool
	for i: int in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		player.name = "SFXPlayer_%d" % i
		add_child(player)
		_sfx_players.append(player)


# ---------------------------------------------------------------------------
# Internal — Stream loading
# ---------------------------------------------------------------------------

func _load_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path] as AudioStream

	if not ResourceLoader.exists(path):
		push_warning("AudioSystem: Audio file not found: %s" % path)
		return null

	var stream: AudioStream = load(path) as AudioStream
	if stream != null:
		_stream_cache[path] = stream
	return stream


# ---------------------------------------------------------------------------
# Internal — Music crossfade
# ---------------------------------------------------------------------------

func _crossfade_music(incoming: AudioStreamPlayer) -> void:
	var outgoing: AudioStreamPlayer = _get_active_music_player()
	_crossfading = true

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	# Fade out old track
	if outgoing.playing and outgoing != incoming:
		tween.tween_property(outgoing, "volume_db", linear_to_db(0.0), _crossfade_duration)

	# Fade in new track
	var target_db: float = linear_to_db(_bus_volumes.get("music", 0.7))
	tween.tween_property(incoming, "volume_db", 0.0, _crossfade_duration)

	tween.set_parallel(false)
	tween.tween_callback(func() -> void:
		if outgoing.playing and outgoing != incoming:
			outgoing.stop()
		_music_active_is_a = (incoming == _music_player_a)
		_crossfading = false
		music_crossfade_completed.emit()
		music_started.emit(_current_music_id)
	)


func _get_active_music_player() -> AudioStreamPlayer:
	return _music_player_a if _music_active_is_a else _music_player_b


func _get_incoming_music_player() -> AudioStreamPlayer:
	return _music_player_b if _music_active_is_a else _music_player_a


# ---------------------------------------------------------------------------
# Internal — SFX pool
# ---------------------------------------------------------------------------

func _get_available_sfx_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			return player
	# All busy — reuse the oldest (first in pool)
	return _sfx_players[0]


# ---------------------------------------------------------------------------
# Internal — Sequential capture SFX
# ---------------------------------------------------------------------------

func _play_capture_sequence() -> void:
	if _pending_captures <= 0:
		return
	play_sfx("piece_captured")
	_pending_captures -= 1
	if _pending_captures > 0:
		get_tree().create_timer(_sfx_capture_gap).timeout.connect(
			_play_capture_sequence, CONNECT_ONE_SHOT
		)


# ---------------------------------------------------------------------------
# Internal — Scene-to-music mapping
# ---------------------------------------------------------------------------

func _scene_to_music_track(scene_key: StringName) -> String:
	match scene_key:
		&"main_menu", &"splash":
			return "main_menu"
		&"tutorial":
			return "tutorial"
		&"credits":
			return "credits"
		_:
			# Match and campaign map music are set by CampaignSystem context,
			# not by scene key alone. Return empty to skip auto-change.
			return ""


# ---------------------------------------------------------------------------
# Internal — App lifecycle
# ---------------------------------------------------------------------------

func _pause_all_audio() -> void:
	_get_active_music_player().stream_paused = true
	_ambient_player.stream_paused = true
	for player: AudioStreamPlayer in _sfx_players:
		if player.playing:
			player.stream_paused = true


func _resume_all_audio() -> void:
	_get_active_music_player().stream_paused = false
	_ambient_player.stream_paused = false
	for player: AudioStreamPlayer in _sfx_players:
		player.stream_paused = false


# ---------------------------------------------------------------------------
# Internal — Signal wiring (deferred to ensure other autoloads are ready)
# ---------------------------------------------------------------------------

func _connect_signals() -> void:
	# Scene Manager
	var scene_mgr: Node = get_node_or_null("/root/SceneManager")
	if scene_mgr != null:
		if scene_mgr.has_signal("scene_changed"):
			scene_mgr.scene_changed.connect(_on_scene_changed)
		if scene_mgr.has_signal("overlay_pushed"):
			scene_mgr.overlay_pushed.connect(_on_overlay_pushed)
		if scene_mgr.has_signal("overlay_popped"):
			scene_mgr.overlay_popped.connect(_on_overlay_popped)
		if scene_mgr.has_signal("app_paused"):
			scene_mgr.app_paused.connect(_on_app_paused)
		if scene_mgr.has_signal("app_resumed"):
			scene_mgr.app_resumed.connect(_on_app_resumed)

	# Board Rules Engine
	var board: Node = get_node_or_null("/root/BoardRules")
	if board != null:
		if board.has_signal("piece_moved"):
			board.piece_moved.connect(_on_piece_moved)
		if board.has_signal("piece_captured"):
			board.piece_captured.connect(_on_piece_captured)
		if board.has_signal("king_threatened"):
			board.king_threatened.connect(_on_king_threatened)
		if board.has_signal("turn_changed"):
			board.turn_changed.connect(_on_turn_changed)
		if board.has_signal("match_ended"):
			board.match_ended.connect(_on_match_ended)


# ---------------------------------------------------------------------------
# Internal — Bus name mapping
# ---------------------------------------------------------------------------

func _bus_name_to_godot(bus_name: String) -> StringName:
	match bus_name:
		"music":
			return BUS_MUSIC
		"sfx":
			return BUS_SFX
		"ambient":
			return BUS_AMBIENT
		_:
			return BUS_MASTER
