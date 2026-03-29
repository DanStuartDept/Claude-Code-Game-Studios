## Scene Manager — Autoload Singleton
##
## Owns the screen flow: scene registry, base scene swapping with fade transitions,
## overlay stack, input blocking during transitions, and mobile app lifecycle.
## Foundation Layer (ADR-0001). Zero upstream dependencies.
##
## Usage:
##   SceneManager.register_scene("match", "res://scenes/match/Match.tscn")
##   SceneManager.change_scene("match")
##   SceneManager.push_overlay("pause")
##   SceneManager.pop_overlay()
##
## See: design/gdd/scene-management.md
extends Node


# --- Signals ---

## Emitted after a base scene change completes (after fade-in).
signal scene_changed(old_key: StringName, new_key: StringName)

## Emitted after an overlay is pushed onto the stack.
signal overlay_pushed(overlay_key: StringName)

## Emitted after an overlay is popped from the stack.
signal overlay_popped(overlay_key: StringName)

## Emitted when the app is backgrounded (mobile).
signal app_paused

## Emitted when the app is resumed from background (mobile).
signal app_resumed


# --- Configuration ---

## Duration of fade-out when changing base scenes (seconds).
var fade_duration_base: float = 0.4

## Duration of fade for overlay push/pop (seconds).
var fade_duration_overlay: float = 0.2

## Whether input is blocked during transitions.
var input_block_during_transition: bool = true

## Arbitrary data to pass to the next scene. Set before calling change_scene().
## The loaded scene can read this in _ready(). Cleared after each scene change.
var scene_data: Dictionary = {}


# --- Internal State ---

## Registry mapping scene keys to packed scene resource paths.
var _registry: Dictionary = {}

## The key of the currently active base scene.
var _current_scene_key: StringName = &""

## The current base scene node instance.
var _current_scene: Node = null

## Stack of overlay entries: Array of { key: StringName, node: Node }.
var _overlay_stack: Array[Dictionary] = []

## Whether a transition is currently in progress.
var _transitioning: bool = false

## Queued scene change request (key) if change_scene called during a transition.
var _queued_scene_key: StringName = &""

## The container node for base scenes.
var _scene_root: Node = null

## The container node for overlays.
var _overlay_root: Node = null

## The CanvasLayer used for the fade transition effect.
var _transition_layer: CanvasLayer = null

## The ColorRect used for the fade effect.
var _fade_rect: ColorRect = null


# --- Lifecycle ---

func _ready() -> void:
	_setup_scene_containers()
	_setup_transition_layer()


func _setup_scene_containers() -> void:
	_scene_root = Node.new()
	_scene_root.name = "SceneRoot"
	add_child(_scene_root)

	_overlay_root = Node.new()
	_overlay_root.name = "OverlayRoot"
	add_child(_overlay_root)


func _setup_transition_layer() -> void:
	_transition_layer = CanvasLayer.new()
	_transition_layer.name = "TransitionLayer"
	_transition_layer.layer = 100  # Above everything
	add_child(_transition_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color(0, 0, 0, 0)  # Start fully transparent
	_fade_rect.anchors_preset = Control.PRESET_FULL_RECT
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_layer.add_child(_fade_rect)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		app_paused.emit()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		app_resumed.emit()


# --- Public API: Registry ---

## Register a scene by key. The path should be a valid .tscn resource path.
##
## Usage:
##   scene_manager.register_scene("match", "res://scenes/match/Match.tscn")
func register_scene(key: StringName, scene_path: String) -> void:
	_registry[key] = scene_path


## Register multiple scenes at once from a dictionary of { key: path }.
##
## Usage:
##   scene_manager.register_scenes({ &"menu": "res://scenes/Menu.tscn", &"match": "res://scenes/Match.tscn" })
func register_scenes(scenes: Dictionary) -> void:
	for key in scenes:
		_registry[key] = scenes[key]


## Return whether a scene key is registered.
func has_scene(key: StringName) -> bool:
	return _registry.has(key)


## Return the currently active base scene key.
func get_current_scene_key() -> StringName:
	return _current_scene_key


## Return a reference to the current base scene node, or null.
func get_current_scene() -> Node:
	return _current_scene


## Return the number of overlays currently on the stack.
func get_overlay_count() -> int:
	return _overlay_stack.size()


## Return whether a transition is in progress.
func is_transitioning() -> bool:
	return _transitioning


# --- Public API: Scene Control ---

## Change the active base scene. Fades out, swaps scenes, fades in.
## If called during a transition, the request is queued.
## Clears all overlays before changing.
func change_scene(key: StringName) -> void:
	if not _registry.has(key):
		push_warning("SceneManager: Scene key '%s' not found in registry" % key)
		return

	if _transitioning:
		_queued_scene_key = key
		return

	_transitioning = true

	if input_block_during_transition:
		_block_input(true)

	# Clear overlays first (instantly, no fade)
	_clear_overlays_immediate()

	var old_key := _current_scene_key

	# If there's a current scene, fade out first
	if _current_scene != null:
		await _fade(0.0, 1.0, fade_duration_base)
		_unload_current_scene()
		_load_scene(key)
		await _fade(1.0, 0.0, fade_duration_base)
	else:
		# No current scene — just load and fade in
		_load_scene(key)
		await _fade(1.0, 0.0, fade_duration_base)

	if input_block_during_transition:
		_block_input(false)

	_transitioning = false

	scene_changed.emit(old_key, _current_scene_key)

	# Process queued scene change
	if _queued_scene_key != &"":
		var next_key := _queued_scene_key
		_queued_scene_key = &""
		change_scene(next_key)


## Push an overlay scene onto the stack. Fades in the overlay.
## The base scene remains loaded but overlays receive input priority.
func push_overlay(key: StringName) -> void:
	if not _registry.has(key):
		push_warning("SceneManager: Overlay key '%s' not found in registry" % key)
		return

	if _transitioning:
		return

	_transitioning = true

	if input_block_during_transition:
		_block_input(true)

	var scene_path: String = _registry[key]
	var packed: PackedScene = load(scene_path)
	var instance: Node = packed.instantiate()
	_overlay_root.add_child(instance)

	var entry := { "key": key, "node": instance }
	_overlay_stack.append(entry)

	await _fade_overlay(instance, 0.0, 1.0, fade_duration_overlay)

	if input_block_during_transition:
		_block_input(false)

	_transitioning = false
	overlay_pushed.emit(key)


## Pop the topmost overlay from the stack. Fades it out and removes it.
## No-op if the overlay stack is empty.
func pop_overlay() -> void:
	if _overlay_stack.is_empty():
		push_warning("SceneManager: pop_overlay() called with empty overlay stack")
		return

	if _transitioning:
		return

	_transitioning = true

	if input_block_during_transition:
		_block_input(true)

	var entry: Dictionary = _overlay_stack.pop_back()
	var overlay_node: Node = entry.node
	var overlay_key: StringName = entry.key

	await _fade_overlay(overlay_node, 1.0, 0.0, fade_duration_overlay)

	overlay_node.queue_free()

	if input_block_during_transition:
		_block_input(false)

	_transitioning = false
	overlay_popped.emit(overlay_key)


## Pop all overlays from the stack immediately (no fade).
func pop_all_overlays() -> void:
	while not _overlay_stack.is_empty():
		var entry: Dictionary = _overlay_stack.pop_back()
		var overlay_node: Node = entry.node
		var overlay_key: StringName = entry.key
		overlay_node.queue_free()
		overlay_popped.emit(overlay_key)


# --- Internal: Scene Loading ---

func _load_scene(key: StringName) -> void:
	var scene_path: String = _registry[key]
	var packed: PackedScene = load(scene_path)
	_current_scene = packed.instantiate()
	_scene_root.add_child(_current_scene)
	_current_scene_key = key


func _unload_current_scene() -> void:
	if _current_scene != null:
		_current_scene.queue_free()
		_current_scene = null
		_current_scene_key = &""


func _clear_overlays_immediate() -> void:
	while not _overlay_stack.is_empty():
		var entry: Dictionary = _overlay_stack.pop_back()
		entry.node.queue_free()


# --- Internal: Transitions ---

func _fade(from_alpha: float, to_alpha: float, duration: float) -> void:
	_fade_rect.color.a = from_alpha
	if duration <= 0.0:
		_fade_rect.color.a = to_alpha
		return

	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", to_alpha, duration)
	await tween.finished


func _fade_overlay(overlay: Node, from_alpha: float, to_alpha: float, duration: float) -> void:
	if overlay is CanvasItem:
		(overlay as CanvasItem).modulate.a = from_alpha
		if duration <= 0.0:
			(overlay as CanvasItem).modulate.a = to_alpha
			return
		var tween := create_tween()
		tween.tween_property(overlay, "modulate:a", to_alpha, duration)
		await tween.finished
	else:
		# Non-CanvasItem overlays don't fade — just wait the duration
		if duration > 0.0:
			await get_tree().create_timer(duration).timeout


func _block_input(block: bool) -> void:
	if block:
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
