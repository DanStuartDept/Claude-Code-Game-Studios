# Scene Management

> **Status**: Designed
> **Author**: user + game-designer
> **Last Updated**: 2026-03-28
> **Implements Pillar**: Infrastructure — the app skeleton that holds everything together

## Overview

Scene Management is the application skeleton for Fidchell. It owns the screen flow — which screen is active, how transitions between screens work, and the lifecycle of each scene (load, display, unload). The system manages five core screens: splash/loading, main menu, campaign map, match, and settings. It provides a scene stack for overlay screens (pause, dialogue, match result) that layer on top of the active base screen without destroying it. The player never interacts with this system directly — they experience it as the seamless flow from menu to match to result and back. On mobile, it also handles app lifecycle events (backgrounding, resuming, low memory).

## Player Fantasy

The player should never think about scene management. Screens should feel like places — the main menu is the starting hearth, the campaign map is the journey, the match is the table. Transitions between them should be smooth and unhurried, matching the game's quiet, grounded tone. Nothing should pop or jar. Loading should be invisible or masked by atmosphere (a brief landscape, a flicker of firelight). Returning to the game after backgrounding should feel like sitting back down at the table — everything exactly where you left it.

## Detailed Design

### Core Rules

#### 1. Scene Types

Two categories of scenes:

| Type | Behaviour | Examples |
|------|-----------|---------|
| **Base Scene** | Full-screen, only one active at a time. Switching base scenes unloads the previous one. | Splash, Main Menu, Campaign Map, Match |
| **Overlay Scene** | Layers on top of the active base scene. Base scene remains loaded but paused/dimmed. Multiple overlays can stack. | Pause Menu, Dialogue, Match Result, Settings |

#### 2. Scene Registry

All scenes are registered by name. The scene manager loads them by key, not by file path.

| Scene Key | Type | Description |
|-----------|------|-------------|
| `splash` | Base | App launch — studio logo, loading |
| `main_menu` | Base | Title screen — New Game, Continue, Quick Play, Settings, Credits |
| `campaign_map` | Base | Chapter/opponent selection, reputation display |
| `match` | Base | The Fidchell board — gameplay happens here |
| `settings` | Overlay | Audio, display, controls, accessibility |
| `pause` | Overlay | Pause during match — Resume, Settings, Quit Match |
| `dialogue` | Overlay | Pre/post match dialogue with opponent portrait |
| `match_result` | Overlay | Win/loss screen — reputation earned, feud status |
| `credits` | Overlay | Scrolling credits |

#### 3. Scene Stack

The scene manager maintains a stack:
- **Bottom**: Always the active base scene
- **Top**: Zero or more overlay scenes

Operations:
- `change_scene(key)` — Unload current base scene, load new base scene. Clears all overlays.
- `push_overlay(key)` — Push an overlay onto the stack. Base scene pauses.
- `pop_overlay()` — Remove the top overlay. If no overlays remain, base scene resumes.
- `pop_all_overlays()` — Clear the entire overlay stack.

#### 4. Transitions

All scene changes use a transition effect. The default is a simple fade:

| Transition | Duration | Used For |
|------------|----------|----------|
| **Fade to black** | 0.4s out, 0.4s in | Base scene changes (menu → match, match → campaign map) |
| **Fade overlay** | 0.2s in/out | Overlay push/pop (dialogue appearing, pause menu) |
| **Cut** | Instant | Splash → main menu (after loading completes) |

Transitions are cosmetic — the scene manager handles load/unload during the black frame.

#### 5. Scene Lifecycle

Each scene follows a standard lifecycle:

```
load → ready → enter_transition → active → exit_transition → unload
```

| Phase | What Happens |
|-------|-------------|
| `load` | Scene resources are loaded into memory. May be async. |
| `ready` | Scene is loaded but not visible. Initialize state. |
| `enter_transition` | Transition effect plays (fade in). |
| `active` | Scene is visible and receiving input. |
| `exit_transition` | Transition effect plays (fade out). |
| `unload` | Scene resources are freed. Overlays are not unloaded — just hidden/paused. |

#### 6. Mobile App Lifecycle

| Event | Behaviour |
|-------|-----------|
| **App backgrounded** | Pause game logic (stop AI think timer, pause match clock if any). Save session state via Save System. |
| **App resumed** | Restore from paused state. No reload needed — scene tree remains in memory. |
| **Low memory warning** | Unload non-essential cached resources (audio buffers, unused scene assets). Keep active scene intact. |
| **App terminated** | Save System handles persistence. Scene manager does nothing — the OS kills the process. |

#### 7. Screen Flow

```
Splash → Main Menu → Campaign Map → [Dialogue] → Match → [Match Result] → Campaign Map
                   → Quick Play → Match → [Match Result] → Main Menu
                   → Settings (overlay)
                   → Credits (overlay)
```

The primary flow is: **Main Menu → Campaign Map → Dialogue → Match → Result → Campaign Map** (loop).

### States and Transitions

The scene manager itself has a simple state:

| State | Behaviour | Exit Condition |
|-------|-----------|----------------|
| **Loading** | App startup. Loading core resources. Splash screen displayed. | Core resources loaded |
| **Active** | Normal operation. Processing scene changes and overlays. | App terminated or backgrounded |
| **Transitioning** | Playing a transition effect between scenes. Input is blocked. | Transition animation completes |
| **Paused** | App is backgrounded. All game logic frozen. | App resumed |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Board UI** | Board UI is a scene | The match scene contains the Board UI. Scene manager loads/unloads it. No direct API calls. |
| **Campaign System** | Campaign drives scene flow | Campaign calls `change_scene("match")` to start matches, `push_overlay("dialogue")` for dialogue, `push_overlay("match_result")` for results. |
| **Audio System** | Audio listens to scene changes | Audio subscribes to `scene_changed` signal to crossfade music per scene. |
| **Save System** | Save hooks into lifecycle | Scene manager calls Save System on app backgrounded. Save System does not call scene manager. |
| **Dialogue System** | Dialogue is an overlay | Dialogue System calls `push_overlay("dialogue")` and `pop_overlay()` when complete. |
| **Settings** | Settings is an overlay | Settings screen reads/writes user preferences. Scene manager just loads/unloads it. |

**Signals emitted:**

| Signal | Data | When |
|--------|------|------|
| `scene_changed` | old_key, new_key | After a base scene change completes |
| `overlay_pushed` | overlay_key | After an overlay is pushed |
| `overlay_popped` | overlay_key | After an overlay is popped |
| `app_paused` | — | App backgrounded |
| `app_resumed` | — | App resumed from background |

## Formulas

No formulas. This system is pure logic and lifecycle management with no mathematical calculations.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|-------------------|-----------|
| `change_scene` called during a transition | Queue the request, execute after current transition completes | Prevents corrupted state from overlapping transitions |
| `pop_overlay` called with no overlays on stack | No-op, log a warning | Defensive — don't crash on empty stack |
| Multiple overlays stacked (e.g., pause → settings) | Settings is on top, receives input. Pause is below, visible but inactive. | Stack ordering determines input focus |
| App killed by OS without warning | No cleanup runs. Save System's last background-save is the recovery point. | Mobile reality — apps can be killed at any time |
| App resumed after long background period | Check if scene tree is intact. If memory was reclaimed, reload from splash. | OS may have freed resources during extended background |
| Player presses back/swipe-back on Android | If overlay is open: pop overlay. If on main menu: show exit confirmation. If on campaign map or match: push pause overlay. | Standard Android back behaviour |
| Scene load fails (corrupted file, missing resource) | Fall back to main menu with an error message. Never crash. | Graceful degradation |
| Quick Play match ends — return to where? | Return to main menu, not campaign map | Quick Play is separate from campaign flow |

## Dependencies

| System | Direction | Nature | Interface |
|--------|-----------|--------|-----------|
| **Board UI** | Depends on this | Hard — match scene is loaded by scene manager | `change_scene("match")` |
| **Audio System** | Depends on this | Soft — uses `scene_changed` signal for music transitions | `scene_changed` signal |
| **Campaign System** | Uses this | Hard — campaign drives scene flow | `change_scene()`, `push_overlay()`, `pop_overlay()` |
| **Save System** | Uses this | Soft — scene manager triggers save on background | `app_paused` signal |

**This system depends on:** Nothing. It is a foundation layer.

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|--------------------|--------------------|
| `fade_duration_base` | 0.4s | 0.2–0.8s | Slower, more cinematic transitions | Snappier, more responsive |
| `fade_duration_overlay` | 0.2s | 0.1–0.4s | Overlays feel weightier | Overlays feel instant |
| `splash_min_duration` | 2.0s | 1.0–4.0s | Longer branding display | Faster to gameplay |
| `input_block_during_transition` | true | true/false | Prevents accidental inputs during fades | Allows input queuing (risky) |

## Acceptance Criteria

- [ ] All 9 scenes load and display correctly
- [ ] Base scene changes unload the previous scene and clear overlays
- [ ] Overlay push/pop works with correct stacking order
- [ ] Transitions play smoothly at 60fps on target mobile hardware
- [ ] Input is blocked during transitions — no accidental taps
- [ ] App backgrounding pauses all game logic
- [ ] App resuming restores state without reload
- [ ] Android back button behaves correctly per context (pop overlay / pause / exit confirmation)
- [ ] Scene change during transition is queued, not dropped or corrupted
- [ ] `scene_changed` signal fires with correct old/new keys
- [ ] Quick Play returns to main menu, campaign returns to campaign map
- [ ] Graceful fallback to main menu on scene load failure
- [ ] No hardcoded scene paths — all scenes registered by key
