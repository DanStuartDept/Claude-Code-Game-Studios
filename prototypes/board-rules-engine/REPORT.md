## Prototype Report: Board Rules Engine

### Hypothesis
The Fidchell board rules (7x7 grid, custodial capture, asymmetric King
mechanics) can be implemented as a pure logic engine that correctly handles
all rules and edge cases from the GDD, validating that the rules are
unambiguous and implementable before building UI or AI on top.

### Approach
- Built a standalone GDScript class (`ProtoBoardRules`, extends `RefCounted`)
  with zero Godot Node dependencies — pure logic
- Implemented: board state, piece placement, legal move generation, custodial
  capture, King 4-sided capture, win condition detection, turn management
- Created 23 automated test cases covering every edge case from the GDD
- Total implementation: ~250 lines of rules engine, ~350 lines of tests
- Shortcuts taken: no signals (direct return values), no scripted mode,
  hardcoded starting layout, no match mode enum

### Result
**VALIDATED** — All 63 assertions pass in Godot 4.6.1 headless mode.

- All 10 GDD edge cases have corresponding test cases
- Legal move generation handles: orthogonal movement, piece blocking, throne/corner restrictions
- Capture logic handles: basic custodial, multi-capture, corner-hostile, throne-hostile, voluntary sandwich immunity
- King capture handles: 4-sided enclosure, 3-attacker + hostile tile, 3-attacker + defender (no capture), king-on-throne immunity
- Win conditions: King escape (priority over captures), King surrounded, no legal moves = loss
- Turn order: Attackers first, strict alternation, wrong-side move rejection

### Metrics
- **Code size**: ~600 lines total (250 engine + 350 tests)
- **Test coverage**: 23 test cases, 63 individual assertions (all passing)
- **GDD edge cases covered**: 10/10 (all from the Edge Cases table)
- **Frame time**: N/A (pure logic, no rendering)
- **Iteration count**: 1 (rules were unambiguous enough to implement directly)

### Recommendation: PROCEED

The GDD's rules are precise and unambiguous — every edge case translated
directly into a testable scenario with no interpretation needed. The
implementation is straightforward (~250 lines for the complete rules engine),
confirming this system is low-risk from a complexity standpoint. The real risk
lives in the AI System (which builds on top of this) and Board UI (touch
controls on mobile), not in the rules themselves.

### If Proceeding
- **Architecture**: Move to Autoload singleton per ADR-0001, add Godot signals
  for all events (piece_moved, piece_captured, turn_changed, match_ended,
  king_threatened)
- **Add scripted mode**: For the Prologue's predetermined loss
- **Add match mode enum**: Standard vs Scripted
- **Use custom Resources**: BoardLayout resource for starting positions instead
  of hardcoded arrays
- **Performance target**: Legal move generation < 1ms on mobile (should be
  trivial for 7x7 grid)
- **Testing**: Port test cases to GdUnit4, add property-based tests for move
  generation (fuzz random board states)
- **Estimated production effort**: Small (1 session) — the prototype is close
  to production shape, just needs signals, resources, and proper structure

### Lessons Learned
1. **The GDD was implementation-ready** — no ambiguity discovered during
   prototyping. The 8-section format (especially Edge Cases and Formulas)
   paid off: every rule mapped directly to code.
2. **Pure logic separation works well** — having no Node dependency means the
   rules engine can be tested without a scene tree. This validates the ADR-0001
   decision to keep Board Rules as pure logic with UI as a separate consumer.
3. **The `_is_hostile()` helper is the key abstraction** — it unifies enemy
   pieces, corner tiles, and empty throne into one concept, keeping capture
   logic clean. Production code should preserve this pattern.
4. **King capture is simpler than expected** — the 4-sided check is just a
   count of hostile neighbors. The complexity is in defining "hostile"
   correctly (corners always, throne only when empty, king-occupied throne
   is not hostile).
