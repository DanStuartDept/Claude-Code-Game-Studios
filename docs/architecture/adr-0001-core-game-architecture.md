# ADR-0001: Core Game Architecture

## Status
Accepted

## Date
2026-03-28

## Context

### Problem Statement
Fidchell has 12 designed systems that need a clear structural foundation before
prototyping begins. We need to decide how systems are organized, how they
communicate, how state is managed, and how Godot's features map to our design.
This is a solo-developer first game targeting mobile — simplicity and
debuggability matter more than theoretical purity.

### Constraints
- Solo developer, first game — architecture must be simple to work in
- Mobile target (iOS/Android) — memory and performance awareness needed
- Godot 4.6 with GDScript — should use idiomatic Godot patterns
- 12 systems with well-defined dependencies (see systems-index.md)

### Requirements
- Systems must be independently testable
- Communication between systems must be traceable (debuggable)
- Adding new systems (e.g., Audio, Tutorial) must not require modifying existing ones
- Data must be externalized, not hardcoded in scripts

## Decision

### 1. Layered System Architecture

Systems are organized into dependency layers. A system may only depend on systems
in its own layer or below — never above.

```
┌─────────────────────────────────────────────────┐
│  Polish Layer                                   │
│  Tutorial System, Audio System                  │
├─────────────────────────────────────────────────┤
│  Presentation Layer                             │
│  Campaign UI                                    │
├─────────────────────────────────────────────────┤
│  Feature Layer                                  │
│  Campaign, Reputation, Feud, Dialogue, Save     │
├─────────────────────────────────────────────────┤
│  Core Layer                                     │
│  AI System, Board UI                            │
├─────────────────────────────────────────────────┤
│  Foundation Layer                               │
│  Board Rules Engine, Scene Management           │
└─────────────────────────────────────────────────┘
```

**Rule:** Arrows point down only. Foundation systems have zero dependencies.
Core depends on Foundation. Feature depends on Core and Foundation. And so on.

### 2. Autoload Singletons for Core Managers

The following systems are registered as Godot Autoloads (global singletons),
loaded at app startup in this order:

| Load Order | Autoload Name     | Script                              | Why Autoload                              |
|------------|-------------------|-------------------------------------|-------------------------------------------|
| 1          | SceneManager      | `src/core/scene_manager.gd`         | Manages all scene transitions globally    |
| 2          | BoardRules        | `src/core/board_rules.gd`           | Pure logic engine, queried by many systems|
| 3          | AISystem          | `src/core/ai_system.gd`             | Needs to persist across scene changes     |
| 4          | CampaignSystem    | `src/gameplay/campaign_system.gd`   | Drives game flow, outlives any single scene|
| 5          | ReputationSystem  | `src/gameplay/reputation_system.gd` | Persistent campaign state                 |
| 6          | FeudSystem        | `src/gameplay/feud_system.gd`       | Persistent campaign state                 |
| 7          | SaveSystem        | `src/gameplay/save_system.gd`       | Must be accessible from anywhere          |

Systems that are **not** Autoloads (they live inside scenes):

| System          | Lives In                  | Why Not Autoload                        |
|-----------------|---------------------------|-----------------------------------------|
| Board UI        | Match scene               | Only exists during a match              |
| Campaign UI     | Campaign Map scene        | Only exists on the campaign screen      |
| Dialogue System | Dialogue overlay scene    | Only exists during dialogue             |
| Tutorial System | Match scene (when active) | Only exists during tutorial matches      |
| Audio System    | Autoload (exception)      | Persists across scenes for crossfade    |

**Audio System is also an Autoload** (load order 8) because music must crossfade
between scenes without interruption.

### 3. Signal-Driven Communication

Systems communicate primarily through Godot signals. The pattern:

- **Downstream systems emit signals** — Board Rules emits `piece_captured`,
  Campaign emits `chapter_unlocked`, etc.
- **Upstream systems connect to signals** — Board UI connects to Board Rules'
  `piece_moved` signal, Audio connects to `scene_changed`, etc.
- **No system calls into a system above its layer** — Board Rules never calls
  Board UI. Campaign never calls Campaign UI.
- **Same-layer and downward calls are allowed** — Campaign calls
  `BoardRules.start_match()`, AI calls `BoardRules.get_legal_moves()`.

```
Board Rules Engine                    Scene Manager
  ├── piece_moved ──→ Board UI          ├── scene_changed ──→ Audio System
  ├── piece_captured ──→ Board UI       ├── overlay_pushed ──→ (any listener)
  ├── piece_captured ──→ Audio System   └── overlay_popped ──→ (any listener)
  ├── turn_changed ──→ Board UI
  ├── match_ended ──→ Campaign System
  ├── match_ended ──→ Board UI
  ├── king_threatened ──→ Board UI
  └── king_threatened ──→ Audio System
```

**Why signals over direct calls upward:** Signals are Godot-native, keep systems
decoupled, and make it trivial to add new listeners (Audio, Tutorial) without
touching existing code.

### 4. Distributed State Ownership

Each system owns and manages its own state. There is no central state store.

| System           | State It Owns                                          | Persisted? |
|------------------|--------------------------------------------------------|------------|
| BoardRules       | Board grid, piece positions, active side, match status | No (per-match) |
| AISystem         | Current search state, think timer                      | No         |
| CampaignSystem   | Current chapter, match history, opponent roster        | Yes        |
| ReputationSystem | Reputation score, bonus history                        | Yes        |
| FeudSystem       | Active feuds, feud states, rematch queue               | Yes        |
| SaveSystem       | Save slot metadata                                     | Yes (it IS persistence) |
| SceneManager     | Scene stack, current base scene                        | No         |

**Persistence rule:** Systems that need saving expose `get_save_data() -> Dictionary`
and `load_save_data(data: Dictionary)`. The Save System calls these — it doesn't
reach into other systems' internals.

### 5. Godot Resources for Game Data

All externalized game data uses Godot's Resource system (`.tres` files):

| Data Type           | Resource Class     | Location                    |
|---------------------|--------------------|-----------------------------|
| Board layout        | `BoardLayout`      | `assets/data/board/`        |
| Opponent profiles   | `OpponentProfile`  | `assets/data/opponents/`    |
| Chapter definitions | `ChapterData`      | `assets/data/campaign/`     |
| AI personality      | `AIPersonality`    | `assets/data/ai/`           |
| Tuning parameters   | `TuningConfig`     | `assets/data/tuning/`       |

**Why Resources over JSON:**
- Type-safe — the editor validates fields
- Native — `load()` and `preload()` just work, no parsing
- Inspector-friendly — designers can tweak values in the Godot editor
- Exportable — custom Resource classes with `@export` variables

### 6. Scene Tree Structure

```
root
├── SceneManager (Autoload)
├── BoardRules (Autoload)
├── AISystem (Autoload)
├── CampaignSystem (Autoload)
├── ReputationSystem (Autoload)
├── FeudSystem (Autoload)
├── SaveSystem (Autoload)
├── AudioSystem (Autoload)
│
└── CurrentScene (managed by SceneManager)
    ├── [Base Scene — e.g., Match]
    │   ├── BoardUI
    │   ├── HUD
    │   └── ...
    └── [Overlay Stack]
        ├── DialogueOverlay
        └── PauseOverlay
```

SceneManager owns a designated node where it swaps base scenes and stacks overlays.

### Key Interfaces

**BoardRules (public API):**
```gdscript
func start_match(mode: MatchMode, side: Side) -> void
func get_board_state() -> BoardState
func get_legal_moves(piece: Vector2i) -> Array[Vector2i]
func get_all_legal_moves(side: Side) -> Array[Move]
func submit_move(from: Vector2i, to: Vector2i) -> MoveResult

signal piece_moved(piece: Vector2i, from_pos: Vector2i, to_pos: Vector2i)
signal piece_captured(piece: Vector2i, position: Vector2i, captured_by: Vector2i)
signal turn_changed(new_side: Side)
signal match_ended(result: MatchResult)
signal king_threatened(king_pos: Vector2i, threat_count: int)
```

**SceneManager (public API):**
```gdscript
func change_scene(key: StringName) -> void
func push_overlay(key: StringName) -> void
func pop_overlay() -> void
func pop_all_overlays() -> void

signal scene_changed(old_key: StringName, new_key: StringName)
signal overlay_pushed(key: StringName)
signal overlay_popped(key: StringName)
```

**Save/Load interface (implemented by persistent systems):**
```gdscript
func get_save_data() -> Dictionary
func load_save_data(data: Dictionary) -> void
```

## Alternatives Considered

### Alternative 1: Centralized State Store (Redux-style)
- **Description**: Single global dictionary holds all game state. Systems read
  from and dispatch actions to the store.
- **Pros**: Single source of truth, easy to serialize for save/load, time-travel
  debugging possible.
- **Cons**: Unidiomatic in Godot, adds indirection, requires action/reducer
  boilerplate, harder to reason about for a first project.
- **Rejection Reason**: Over-engineered for this scope. Distributed ownership
  with signals is simpler and matches how Godot naturally works.

### Alternative 2: Scene-Tree Dependency Injection
- **Description**: Pass system references through the scene tree via `@export`
  or `@onready` node paths. No Autoloads.
- **Pros**: Explicitly wired, easier to unit test with mock objects, no global state.
- **Cons**: Verbose wiring for every scene, brittle if scene tree changes,
  Campaign and Save systems need to outlive individual scenes.
- **Rejection Reason**: Too much ceremony for a solo project. Autoloads are the
  standard Godot approach for managers that span the app lifecycle.

### Alternative 3: JSON for Game Data
- **Description**: Store opponent profiles, board layouts, and tuning values as
  JSON files parsed at runtime.
- **Pros**: Human-readable, easy to diff in version control, language-agnostic.
- **Cons**: No type safety, requires manual parsing/validation, no editor
  integration, can't use `@export` or inspector.
- **Rejection Reason**: Godot Resources provide all the benefits of external data
  with type safety and editor support built in.

## Consequences

### Positive
- Simple mental model: "Autoloads are managers, scenes are views, signals are events"
- Adding new systems (Audio, Tutorial) only requires connecting to existing signals
- Each system can be developed and tested independently
- Idiomatic Godot — any Godot tutorial or resource applies directly
- Save/load is clean: call `get_save_data()` on each persistent system, done

### Negative
- Autoloads are global state — harder to unit test in isolation (must use
  Godot's test runner, not pure GDScript unit tests)
- Signal connections are implicit — need to document which systems connect to which
  signals (this ADR and the GDDs serve that purpose)
- All Autoloads are loaded at startup even if not needed yet (negligible cost
  for 8 lightweight scripts)

### Risks
- **Signal spaghetti**: As systems multiply, signal connections could become hard
  to trace. **Mitigation**: Each system documents its signal connections in its
  GDD. Keep connections in `_ready()` functions, never in random methods.
- **Autoload ordering issues**: Systems initialized before their dependencies.
  **Mitigation**: Explicit load order defined above. Foundation before Core
  before Feature. Godot processes Autoloads in project settings order.
- **Resource class changes break `.tres` files**: Renaming or removing an
  `@export` field invalidates saved resources. **Mitigation**: Treat Resource
  class APIs as stable once data files exist. Use migration scripts if changes
  are unavoidable.

## Performance Implications
- **CPU**: Negligible architecture overhead. Signals add ~1 microsecond per emit.
  The AI minimax search is the only CPU-intensive operation.
- **Memory**: 8 Autoload scripts are trivial (~few KB each). Board state is a
  7x7 grid. Opponent profiles are small resources. Total system overhead < 1MB.
- **Load Time**: All Autoloads initialize on launch. With no heavy assets, startup
  adds < 100ms. Scene loading is async where needed.
- **Network**: N/A — single-player game.

## Migration Plan
No existing code to migrate. This ADR establishes the architecture for greenfield
development. The `src/` directory structure follows from this decision:

```
src/
├── core/               # Foundation + Core layer Autoloads
│   ├── board_rules.gd
│   ├── ai_system.gd
│   └── scene_manager.gd
├── gameplay/           # Feature layer Autoloads
│   ├── campaign_system.gd
│   ├── reputation_system.gd
│   ├── feud_system.gd
│   └── save_system.gd
├── audio/              # Audio Autoload
│   └── audio_system.gd
├── ui/                 # Scene-bound UI scripts
│   ├── board_ui.gd
│   ├── campaign_ui.gd
│   └── dialogue_ui.gd
└── data/               # Custom Resource class definitions
    ├── board_layout.gd
    ├── opponent_profile.gd
    ├── chapter_data.gd
    ├── ai_personality.gd
    └── tuning_config.gd
```

## Validation Criteria
- A prototype can be built using only Foundation-layer systems (Board Rules +
  Scene Manager) without any Feature-layer code existing
- Adding the Audio System requires zero changes to Board Rules or Scene Manager
  (signal connection only)
- Save/load round-trips correctly: save all persistent systems, reload, and
  verify state matches
- Each Autoload can be tested by calling its methods directly from a test scene

## Related Decisions
- [design/gdd/systems-index.md](../../design/gdd/systems-index.md) — system
  enumeration and dependency map
- [design/gdd/board-rules-engine.md](../../design/gdd/board-rules-engine.md) —
  signal definitions and API surface
- [design/gdd/scene-management.md](../../design/gdd/scene-management.md) — scene
  stack design and lifecycle
- [design/gdd/ai-system.md](../../design/gdd/ai-system.md) — AI architecture
  (two-layer evaluator + personality)
- [design/gdd/campaign-system.md](../../design/gdd/campaign-system.md) — campaign
  flow and match scheduling
