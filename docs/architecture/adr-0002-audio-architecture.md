# ADR-0002: Audio Architecture

## Status
Accepted

## Date
2026-03-29

## Context

### Problem Statement
The game needs an audio system that manages music, SFX, and ambient audio
across scenes and chapters. The system must integrate with existing board
event signals, scene transitions, and the save system — without coupling
to those systems directly.

### Constraints
- Mobile target — audio must be lightweight (battery, memory)
- Signal-driven architecture established by ADR-0001
- No voice acting — audio is atmosphere only
- Placeholder sounds during development (real assets later)
- Volume settings must persist across sessions

### Requirements
- Three independent audio buses (Music, SFX, Ambient)
- All audio paths externalized in JSON config (no hardcoded paths)
- Crossfade support for music and ambient transitions
- Music ducking during dialogue overlays
- Sequential SFX for multi-capture board events
- Save/load integration for volume preferences

## Decision

**AudioSystem as an Autoload singleton** following ADR-0001's Feature Layer
pattern. Signal-driven: listens to BoardRules and SceneManager signals
rather than being called directly by gameplay code.

### Key choices:

1. **Three Godot AudioServer buses** (Music, SFX, Ambient) created at
   runtime if they don't exist. Each bus is independently controllable
   via linear 0.0–1.0 volume mapped to dB.

2. **Dual AudioStreamPlayer for music crossfade** — two players alternate
   as active/incoming. Tween-based crossfade. Avoids the complexity of
   AudioStreamPolyphonic or custom mixing.

3. **SFX pool (8 players)** — pre-allocated pool avoids allocations during
   gameplay. Round-robin reuse when all are busy. Sequential capture SFX
   uses timer-gated queue.

4. **External config** (`assets/data/audio/audio_config.json`) maps event
   IDs to file paths, stores tuning knobs (crossfade duration, duck amount,
   capture gap). No code changes needed to swap audio assets.

5. **Stream caching** — loaded AudioStreams are cached in a dictionary to
   avoid redundant disk reads. Cache is per-session (cleared on quit).

6. **Board UI wiring via public method** — `connect_board_ui(node)` is
   called by MatchController when creating a BoardUI instance, since
   BoardUI is not a persistent autoload. All BoardRules signals are wired
   in the autoload's deferred `_connect_signals()`.

7. **Dialogue ducking in DialogueOverlay** — the overlay calls
   `AudioSystem.duck_music()` on `_ready()` and `unduck_music()` on
   dismiss, since it doesn't use SceneManager's overlay push/pop.

### Alternatives considered:

- **AudioStreamPolyphonic**: More flexible but more complex to manage
  crossfades. Dual-player approach is simpler and sufficient for our needs.
- **Direct calls from gameplay systems**: Rejected per ADR-0001's
  signal-driven principle. Audio listens, it doesn't get called.
- **Audio bus layout in project.godot**: Considered but rejected — creating
  buses at runtime makes the system self-contained and testable without
  project-level configuration.

## Consequences

### Positive
- Zero coupling: gameplay systems never import or call AudioSystem
- Easy asset swapping: change JSON config, not code
- Testable: AudioSystem can be instantiated in unit tests without
  other autoloads (gracefully handles missing dependencies)
- Mobile-friendly: compressed formats (OGG for music, WAV for SFX),
  pool prevents runtime allocation

### Negative
- Board UI wiring requires MatchController to know about AudioSystem
  (one line of coupling)
- Dialogue ducking is in the overlay rather than a centralized handler
  (pragmatic given the overlay's lifecycle)
- Stream cache has no eviction — fine for a game with ~20 audio files,
  would need LRU for a larger project

### Risks
- Placeholder sounds may mask timing issues that only appear with real
  audio assets. Mitigation: test with real assets early in Polish phase.
