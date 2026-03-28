# Prototype: Board Rules Engine

PROTOTYPE - NOT FOR PRODUCTION

## What This Is

Pure GDScript implementation of Fidchell's board rules: 7x7 grid, custodial
capture, King escape/enclosure, and all edge cases from the GDD. No UI, no
scenes — just logic and a test harness.

## How to Run

### Option 1: Godot Headless (recommended)

```bash
cd prototypes/board-rules-engine/
godot --headless --script test_board_rules.gd
```

### Option 2: Attach to Scene

1. Create a new scene in Godot
2. Attach `test_board_rules.gd` to any Node
3. Run the scene — results print to the Output panel

## Files

- `board_rules.gd` — The rules engine (RefCounted, no Node dependency)
- `test_board_rules.gd` — 23 test cases covering all GDD rules and edge cases

## What It Tests

- Board setup and piece counts
- Orthogonal movement with blocking
- Throne/corner tile restrictions (non-king vs king)
- Custodial capture (basic, multi-axis, corner-assisted, throne-assisted)
- Voluntary sandwich immunity
- King 4-sided capture (attackers, hostile tiles, mixed)
- King immunity to 2-sided sandwich and 3-sided enclosure
- Win conditions (escape, capture, no legal moves)
- Turn order and alternation
- King threat counting
