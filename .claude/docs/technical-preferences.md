# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6
- **Language**: GDScript (primary), C++ via GDExtension (performance-critical)
- **Rendering**: Compatibility (OpenGL ES 3.0) — broadest mobile device support
- **Physics**: Jolt (Godot 4.6 default)

## Naming Conventions

- **Classes**: PascalCase (e.g., `PlayerController`)
- **Variables/Functions**: snake_case (e.g., `move_speed`)
- **Signals/Events**: snake_case past tense (e.g., `health_changed`)
- **Files**: snake_case matching class (e.g., `player_controller.gd`)
- **Scenes/Prefabs**: PascalCase matching root node (e.g., `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HEALTH`)

## Performance Budgets

- **Target Framerate**: 60fps (all target devices)
- **Frame Budget**: 16ms
- **Draw Calls**: < 100 per frame (2D board game — should be well under this)
- **Memory Ceiling**: 256MB (comfortable for mobile, leaves headroom for OS)

## Testing

- **Framework**: GdUnit4
- **Minimum Coverage**: 80% for core/gameplay systems, best-effort for UI
- **Required Tests**: Board rules (all capture/win conditions), AI evaluation, reputation formulas, save/load round-trips

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- **ADR-0001**: [Core Game Architecture](../../docs/architecture/adr-0001-core-game-architecture.md) — Layered systems, Autoload singletons, signal-driven communication, distributed state, Godot Resources for data (Accepted 2026-03-28)
