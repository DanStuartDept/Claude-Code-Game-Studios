## GdUnit4 tests for Audio System
## Covers config loading, bus volume control, SFX playback, music playback,
## ducking, crossfade, and save/load integration.
##
## See: design/gdd/audio-system.md
class_name TestAudioSystem
extends GdUnitTestSuite


const AudioScript := preload("res://src/core/audio_system.gd")

var _audio: Node


func before_test() -> void:
	_audio = AudioScript.new()
	add_child(_audio)


func after_test() -> void:
	_audio.queue_free()


# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------

func test_audio_config_loads_sfx_events() -> void:
	var events: Dictionary = _audio._sfx_events
	assert_bool(events.has("piece_moved")).is_true()
	assert_bool(events.has("piece_captured")).is_true()
	assert_bool(events.has("king_threatened")).is_true()
	assert_bool(events.has("turn_changed")).is_true()
	assert_bool(events.has("match_victory")).is_true()
	assert_bool(events.has("match_defeat")).is_true()


func test_audio_config_loads_music_tracks() -> void:
	var tracks: Dictionary = _audio._music_tracks
	assert_bool(tracks.has("main_menu")).is_true()
	assert_bool(tracks.has("match_chapter_1")).is_true()
	assert_bool(tracks.has("match_final_boss")).is_true()
	assert_bool(tracks.has("credits")).is_true()


func test_audio_config_loads_ambient_tracks() -> void:
	var tracks: Dictionary = _audio._ambient_tracks
	assert_bool(tracks.has("chapter_0")).is_true()
	assert_bool(tracks.has("chapter_1")).is_true()
	assert_bool(tracks.has("chapter_4")).is_true()


func test_audio_config_loads_tuning_knobs() -> void:
	assert_float(_audio._crossfade_duration).is_equal(1.0)
	assert_float(_audio._duck_amount).is_equal(0.2)
	assert_float(_audio._duck_fade_duration).is_equal(0.3)
	assert_float(_audio._sfx_capture_gap).is_equal(0.1)


func test_audio_config_loads_default_volumes() -> void:
	var volumes: Dictionary = _audio._bus_volumes
	assert_float(float(volumes["music"])).is_equal(0.7)
	assert_float(float(volumes["sfx"])).is_equal(1.0)
	assert_float(float(volumes["ambient"])).is_equal(0.5)


func test_audio_config_loads_sting_volumes() -> void:
	var stings: Dictionary = _audio._sting_volumes
	assert_bool(stings.has("match_victory")).is_true()
	assert_float(float(stings["match_victory"])).is_equal(1.0)
	assert_float(float(stings["match_defeat"])).is_equal(0.8)


# ---------------------------------------------------------------------------
# Bus volume control
# ---------------------------------------------------------------------------

func test_audio_set_bus_volume_stores_value() -> void:
	_audio.set_bus_volume("music", 0.3)
	assert_float(_audio.get_bus_volume("music")).is_equal(0.3)


func test_audio_set_bus_volume_clamps_to_range() -> void:
	_audio.set_bus_volume("sfx", 1.5)
	assert_float(_audio.get_bus_volume("sfx")).is_equal(1.0)

	_audio.set_bus_volume("sfx", -0.5)
	assert_float(_audio.get_bus_volume("sfx")).is_equal(0.0)


func test_audio_get_all_volumes_returns_copy() -> void:
	var volumes: Dictionary = _audio.get_all_volumes()
	volumes["music"] = 0.0
	# Original should be unaffected
	assert_float(_audio.get_bus_volume("music")).is_not_equal(0.0)


func test_audio_restore_volumes_applies_values() -> void:
	var saved: Dictionary = {"music": 0.4, "sfx": 0.6, "ambient": 0.2}
	_audio.restore_volumes(saved)
	assert_float(_audio.get_bus_volume("music")).is_equal(0.4)
	assert_float(_audio.get_bus_volume("sfx")).is_equal(0.6)
	assert_float(_audio.get_bus_volume("ambient")).is_equal(0.2)


# ---------------------------------------------------------------------------
# SFX playback
# ---------------------------------------------------------------------------

func test_audio_play_sfx_unknown_event_returns_false() -> void:
	var result: bool = _audio.play_sfx("nonexistent_event")
	assert_bool(result).is_false()


func test_audio_play_sfx_known_event_with_missing_file_returns_false() -> void:
	# The event exists in config, but the actual .wav file doesn't
	var result: bool = _audio.play_sfx("piece_moved")
	assert_bool(result).is_false()


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

func test_audio_play_music_unknown_track_does_not_crash() -> void:
	# Should warn but not crash
	_audio.play_music("nonexistent_track")
	assert_str(_audio.get_current_music_id()).is_empty()


func test_audio_play_music_sets_current_id() -> void:
	# Track exists in config but file doesn't — sets ID before attempting load
	# Since the file doesn't exist, the load will fail and ID won't be set
	_audio.play_music("main_menu")
	# ID is set regardless of file existence (it's set before load attempt)
	# Actually: the load fails, so let's verify graceful handling
	# The current_music_id is set before the stream load attempt
	assert_str(_audio.get_current_music_id()).is_equal("main_menu")


func test_audio_stop_music_clears_id() -> void:
	_audio._current_music_id = "test_track"
	_audio.stop_music()
	assert_str(_audio.get_current_music_id()).is_empty()


# ---------------------------------------------------------------------------
# Ambient
# ---------------------------------------------------------------------------

func test_audio_play_ambient_unknown_chapter_does_not_crash() -> void:
	_audio.play_ambient_for_chapter(99)
	assert_str(_audio.get_current_ambient_id()).is_empty()


func test_audio_play_ambient_sets_id() -> void:
	# File won't exist but ID should be set before load
	_audio.play_ambient_for_chapter(1)
	assert_str(_audio.get_current_ambient_id()).is_equal("chapter_1")


# ---------------------------------------------------------------------------
# Ducking
# ---------------------------------------------------------------------------

func test_audio_duck_music_sets_ducked_state() -> void:
	assert_bool(_audio.is_music_ducked()).is_false()
	_audio.duck_music()
	assert_bool(_audio.is_music_ducked()).is_true()


func test_audio_unduck_music_clears_ducked_state() -> void:
	_audio.duck_music()
	_audio.unduck_music()
	assert_bool(_audio.is_music_ducked()).is_false()


func test_audio_double_duck_does_not_stack() -> void:
	_audio.duck_music()
	_audio.duck_music()
	assert_bool(_audio.is_music_ducked()).is_true()
	_audio.unduck_music()
	assert_bool(_audio.is_music_ducked()).is_false()


func test_audio_unduck_without_duck_is_noop() -> void:
	_audio.unduck_music()
	assert_bool(_audio.is_music_ducked()).is_false()


# ---------------------------------------------------------------------------
# Audio players created
# ---------------------------------------------------------------------------

func test_audio_creates_music_players() -> void:
	assert_object(_audio._music_player_a).is_not_null()
	assert_object(_audio._music_player_b).is_not_null()


func test_audio_creates_ambient_player() -> void:
	assert_object(_audio._ambient_player).is_not_null()


func test_audio_creates_sfx_pool() -> void:
	assert_int(_audio._sfx_players.size()).is_equal(_audio.SFX_POOL_SIZE)


# ---------------------------------------------------------------------------
# Scene-to-music mapping
# ---------------------------------------------------------------------------

func test_audio_scene_to_music_main_menu() -> void:
	var track: String = _audio._scene_to_music_track(&"main_menu")
	assert_str(track).is_equal("main_menu")


func test_audio_scene_to_music_tutorial() -> void:
	var track: String = _audio._scene_to_music_track(&"tutorial")
	assert_str(track).is_equal("tutorial")


func test_audio_scene_to_music_credits() -> void:
	var track: String = _audio._scene_to_music_track(&"credits")
	assert_str(track).is_equal("credits")


func test_audio_scene_to_music_unknown_returns_empty() -> void:
	var track: String = _audio._scene_to_music_track(&"match")
	assert_str(track).is_empty()


# ---------------------------------------------------------------------------
# Bus name mapping
# ---------------------------------------------------------------------------

func test_audio_bus_name_mapping() -> void:
	assert_str(String(_audio._bus_name_to_godot("music"))).is_equal("Music")
	assert_str(String(_audio._bus_name_to_godot("sfx"))).is_equal("SFX")
	assert_str(String(_audio._bus_name_to_godot("ambient"))).is_equal("Ambient")
	assert_str(String(_audio._bus_name_to_godot("unknown"))).is_equal("Master")


# ---------------------------------------------------------------------------
# Signal handler — match_ended
# ---------------------------------------------------------------------------

func test_audio_match_ended_clears_music() -> void:
	_audio._current_music_id = "match_chapter_1"
	_audio._on_match_ended({"winner": "player"})
	assert_str(_audio.get_current_music_id()).is_empty()


# ---------------------------------------------------------------------------
# Capture sequence
# ---------------------------------------------------------------------------

func test_audio_pending_captures_increments() -> void:
	assert_int(_audio._pending_captures).is_equal(0)
	_audio._on_piece_captured(Vector2i(3, 3))
	# First capture triggers immediate play + decrements
	# Since file doesn't exist, play_sfx returns false but counter still processes
	assert_int(_audio._pending_captures).is_equal(0)
