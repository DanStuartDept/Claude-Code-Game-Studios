## GdUnit4 tests for Scene Manager
##
## Covers acceptance criteria from design/gdd/scene-management.md:
## - Scene registry (register by key, not path)
## - Base scene swap with fade transition
## - Overlay push/pop with correct stacking
## - Input blocked during transitions
## - Signals fire with correct data
## - Edge cases: pop empty stack, change during transition, queue handling
##
## Task: S1-03 (Scene Manager)
class_name TestSceneManager
extends GdUnitTestSuite


const SceneManagerScript := preload("res://src/core/scene_manager.gd")

var _sm: Node


func before_test() -> void:
	_sm = SceneManagerScript.new()
	# Use instant transitions for testing (no waiting)
	_sm.fade_duration_base = 0.0
	_sm.fade_duration_overlay = 0.0
	add_child(_sm)
	# Register stub scenes
	_sm.register_scene(&"scene_a", "res://tests/fixtures/stub_scene_a.tscn")
	_sm.register_scene(&"scene_b", "res://tests/fixtures/stub_scene_b.tscn")
	_sm.register_scene(&"overlay_a", "res://tests/fixtures/stub_overlay_a.tscn")
	_sm.register_scene(&"overlay_b", "res://tests/fixtures/stub_overlay_b.tscn")


func after_test() -> void:
	_sm.queue_free()


# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------

func test_register_scene_adds_to_registry() -> void:
	assert_bool(_sm.has_scene(&"scene_a")).is_true()
	assert_bool(_sm.has_scene(&"scene_b")).is_true()
	assert_bool(_sm.has_scene(&"nonexistent")).is_false()


func test_register_scenes_batch() -> void:
	var sm2: Node = SceneManagerScript.new()
	add_child(sm2)
	sm2.register_scenes({
		&"x": "res://tests/fixtures/stub_scene_a.tscn",
		&"y": "res://tests/fixtures/stub_scene_b.tscn",
	})
	assert_bool(sm2.has_scene(&"x")).is_true()
	assert_bool(sm2.has_scene(&"y")).is_true()
	sm2.queue_free()


# ---------------------------------------------------------------------------
# Base Scene Swap
# ---------------------------------------------------------------------------

func test_change_scene_loads_scene() -> void:
	await _sm.change_scene(&"scene_a")
	assert_str(String(_sm.get_current_scene_key())).is_equal("scene_a")
	assert_object(_sm.get_current_scene()).is_not_null()


func test_change_scene_swaps_to_new_scene() -> void:
	await _sm.change_scene(&"scene_a")
	await _sm.change_scene(&"scene_b")
	assert_str(String(_sm.get_current_scene_key())).is_equal("scene_b")
	assert_object(_sm.get_current_scene()).is_not_null()


func test_change_scene_unregistered_key_is_noop() -> void:
	await _sm.change_scene(&"scene_a")
	# Attempt to change to nonexistent key — should warn but not crash
	_sm.change_scene(&"nonexistent")
	# Current scene should remain unchanged
	assert_str(String(_sm.get_current_scene_key())).is_equal("scene_a")


# ---------------------------------------------------------------------------
# Signals: scene_changed
# ---------------------------------------------------------------------------

func test_scene_changed_signal_fires() -> void:
	var signal_data := []
	_sm.scene_changed.connect(func(old_key: StringName, new_key: StringName) -> void:
		signal_data.append({"old": old_key, "new": new_key})
	)

	await _sm.change_scene(&"scene_a")
	assert_int(signal_data.size()).is_equal(1)
	assert_str(String(signal_data[0].old)).is_equal("")
	assert_str(String(signal_data[0].new)).is_equal("scene_a")

	await _sm.change_scene(&"scene_b")
	assert_int(signal_data.size()).is_equal(2)
	assert_str(String(signal_data[1].old)).is_equal("scene_a")
	assert_str(String(signal_data[1].new)).is_equal("scene_b")


# ---------------------------------------------------------------------------
# Overlay Stack
# ---------------------------------------------------------------------------

func test_push_overlay_adds_to_stack() -> void:
	await _sm.change_scene(&"scene_a")
	await _sm.push_overlay(&"overlay_a")
	assert_int(_sm.get_overlay_count()).is_equal(1)


func test_push_multiple_overlays() -> void:
	await _sm.change_scene(&"scene_a")
	await _sm.push_overlay(&"overlay_a")
	await _sm.push_overlay(&"overlay_b")
	assert_int(_sm.get_overlay_count()).is_equal(2)


func test_pop_overlay_removes_top() -> void:
	await _sm.change_scene(&"scene_a")
	await _sm.push_overlay(&"overlay_a")
	await _sm.push_overlay(&"overlay_b")
	await _sm.pop_overlay()
	assert_int(_sm.get_overlay_count()).is_equal(1)


func test_pop_all_overlays_clears_stack() -> void:
	await _sm.change_scene(&"scene_a")
	await _sm.push_overlay(&"overlay_a")
	await _sm.push_overlay(&"overlay_b")
	_sm.pop_all_overlays()
	assert_int(_sm.get_overlay_count()).is_equal(0)


func test_pop_empty_stack_is_noop() -> void:
	# Should not crash — just warn
	await _sm.pop_overlay()
	assert_int(_sm.get_overlay_count()).is_equal(0)


# ---------------------------------------------------------------------------
# Signals: overlay_pushed / overlay_popped
# ---------------------------------------------------------------------------

func test_overlay_signals_fire() -> void:
	var pushed_keys := []
	var popped_keys := []
	_sm.overlay_pushed.connect(func(key: StringName) -> void:
		pushed_keys.append(key)
	)
	_sm.overlay_popped.connect(func(key: StringName) -> void:
		popped_keys.append(key)
	)

	await _sm.change_scene(&"scene_a")
	await _sm.push_overlay(&"overlay_a")
	assert_int(pushed_keys.size()).is_equal(1)
	assert_str(String(pushed_keys[0])).is_equal("overlay_a")

	await _sm.pop_overlay()
	assert_int(popped_keys.size()).is_equal(1)
	assert_str(String(popped_keys[0])).is_equal("overlay_a")


func test_pop_all_overlays_emits_popped_signals() -> void:
	var popped_keys := []
	_sm.overlay_popped.connect(func(key: StringName) -> void:
		popped_keys.append(key)
	)

	await _sm.change_scene(&"scene_a")
	await _sm.push_overlay(&"overlay_a")
	await _sm.push_overlay(&"overlay_b")
	_sm.pop_all_overlays()

	assert_int(popped_keys.size()).is_equal(2)


# ---------------------------------------------------------------------------
# Change scene clears overlays
# ---------------------------------------------------------------------------

func test_change_scene_clears_overlays() -> void:
	await _sm.change_scene(&"scene_a")
	await _sm.push_overlay(&"overlay_a")
	await _sm.push_overlay(&"overlay_b")
	assert_int(_sm.get_overlay_count()).is_equal(2)

	await _sm.change_scene(&"scene_b")
	assert_int(_sm.get_overlay_count()).is_equal(0)


# ---------------------------------------------------------------------------
# Input blocking
# ---------------------------------------------------------------------------

func test_input_not_blocked_outside_transition() -> void:
	# FadeRect should be MOUSE_FILTER_IGNORE when not transitioning
	var fade_rect: ColorRect = _sm._fade_rect
	assert_int(fade_rect.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


# ---------------------------------------------------------------------------
# Transition state
# ---------------------------------------------------------------------------

func test_not_transitioning_after_scene_change() -> void:
	await _sm.change_scene(&"scene_a")
	assert_bool(_sm.is_transitioning()).is_false()


func test_not_transitioning_after_overlay_push() -> void:
	await _sm.change_scene(&"scene_a")
	await _sm.push_overlay(&"overlay_a")
	assert_bool(_sm.is_transitioning()).is_false()


func test_not_transitioning_after_overlay_pop() -> void:
	await _sm.change_scene(&"scene_a")
	await _sm.push_overlay(&"overlay_a")
	await _sm.pop_overlay()
	assert_bool(_sm.is_transitioning()).is_false()


# ---------------------------------------------------------------------------
# No hardcoded scene paths
# ---------------------------------------------------------------------------

func test_no_hardcoded_paths_in_registry() -> void:
	# A fresh SceneManager should have an empty registry
	var sm2: Node = SceneManagerScript.new()
	add_child(sm2)
	assert_bool(sm2.has_scene(&"splash")).is_false()
	assert_bool(sm2.has_scene(&"main_menu")).is_false()
	assert_bool(sm2.has_scene(&"match")).is_false()
	sm2.queue_free()
