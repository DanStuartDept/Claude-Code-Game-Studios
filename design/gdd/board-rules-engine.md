# Board Rules Engine

> **Status**: Designed
> **Author**: user + game-designer
> **Last Updated**: 2026-03-28
> **Implements Pillar**: Core gameplay — the rules of Fidchell

## Overview

The Board Rules Engine is the core rules system for Fidchell, an asymmetric two-player strategy game played on a 7×7 grid. It owns the board data model (grid, tiles, pieces), move validation (orthogonal movement with no jumping), custodial capture logic (including special King capture requiring four-sided enclosure), and win condition detection (King reaches a corner, King is surrounded, or a player has no legal moves). The engine is a pure logic system with no rendering or input handling — it receives moves, validates them, applies state changes, and emits events that other systems (AI, Board UI, Campaign) consume. It is the foundation every other system builds on; if the rules are wrong, everything above them is wrong.

## Player Fantasy

The player should feel like they are playing a game with ancient weight — simple rules that produce deep consequences. Every move should feel deliberate: one piece, one direction, and the board shifts. Captures should feel like sprung traps — a piece is safe until suddenly it isn't. The King's vulnerability (needing four-sided enclosure to capture) should make the Attacker's task feel like a slow hunt, while the Defender experiences a tense escape. The asymmetry is the heart of the fantasy: Attackers feel like wolves circling; Defenders feel like a royal guard holding the line. The rules engine serves this by being fast, correct, and invisible — the player should never think about the system, only about the board.

## Detailed Design

### Core Rules

#### 1. The Board

A 7×7 grid. Each cell is one of three tile types:

| Tile Type | Positions | Rules |
|-----------|-----------|-------|
| **Normal** | All cells except those listed below | Any piece may occupy |
| **Throne** | Centre (3,3) | Only the King may enter. Acts as hostile for capture when empty. |
| **Corner** | (0,0), (0,6), (6,0), (6,6) | Only the King may enter. Act as hostile for capture. Defender wins if King reaches one. |

Coordinates use (row, col), 0-indexed, with (0,0) at top-left.

#### 2. The Pieces

| Piece | Side | Count | Special Rules |
|-------|------|-------|---------------|
| **Attacker** | Dark | 16 | Standard movement and capture. Moves first. |
| **Defender** | Light | 8 | Standard movement and capture. |
| **King** | Light | 1 | May enter Throne and Corner tiles. Requires 4-sided enclosure to capture. |

Total: 25 pieces on 49 squares.

#### 3. Starting Layout

```
     0   1   2   3   4   5   6
  0  .   .   A   A   A   .   .
  1  .   .   .   A   .   .   .
  2  A   .   D   D   D   .   A
  3  A   A   D   K   D   A   A
  4  A   .   D   D   D   .   A
  5  .   .   .   A   .   .   .
  6  .   .   A   A   A   .   .
```

**Attackers (16):** (0,2), (0,3), (0,4), (1,3), (2,0), (2,6), (3,0), (3,1), (3,5), (3,6), (4,0), (4,6), (5,3), (6,2), (6,3), (6,4)

**Defenders (8):** (2,2), (2,3), (2,4), (3,2), (3,4), (4,2), (4,3), (4,4)

**King (1):** (3,3) — on the Throne

Defenders form a protective ring around the King. Attackers are arranged in T-formations at each edge, pointing inward.

#### 4. Turn Order

1. Attackers (Dark) always move first
2. Players alternate turns — one move per turn
3. A player must move exactly one piece per turn

#### 5. Movement

1. Select one friendly piece
2. Move it orthogonally (up, down, left, or right) any number of squares in a straight line
3. The piece may not jump over other pieces
4. The piece may not land on an occupied square
5. Non-King pieces may not land on Throne or Corner tiles
6. The King may land on any unoccupied tile, including Throne and Corners

#### 6. Capture — Standard Pieces

A piece (Attacker or Defender) is captured and removed from the board when:

1. An enemy piece moves to create a sandwich — the target piece is between the moved piece and another enemy piece (or hostile tile) on opposite sides along a row or column
2. Both flanking positions must be on the same axis (horizontal or vertical)
3. The capture must be **active** — the moving piece must be one of the flanking pieces. A piece that moves *into* a sandwich voluntarily is not captured.
4. Multiple captures may occur from a single move if the moved piece simultaneously flanks multiple enemies on different axes

**Hostile tiles for capture:** The four Corner tiles and the empty Throne act as enemy pieces for capture purposes. A single piece flanked between an enemy piece and a hostile tile is captured.

#### 7. Capture — The King

The King cannot be captured by a standard two-sided sandwich. The King is captured when:

1. **Four-sided enclosure:** Enemy pieces occupy all four orthogonally adjacent cells (up, down, left, right)
2. **Three sides plus hostile tile:** Enemy pieces occupy three adjacent cells and the fourth is a hostile tile (Corner or empty Throne)

The King is never captured by a two-sided sandwich.

#### 8. Win Conditions

| Condition | Winner | Detection |
|-----------|--------|-----------|
| King reaches any Corner tile | Defenders | Check after each Defender move |
| King surrounded on all 4 sides | Attackers | Check after each Attacker move |
| Player has no legal moves on their turn | Opponent | Check at start of turn |

The game ends immediately when any win condition is met. No further moves are processed.

#### 9. Match Modes

| Mode | Description | Used By |
|------|-------------|---------|
| **Standard** | Full rules, both sides playable, result determined by gameplay | Campaign matches, quick play |
| **Scripted** | Board state is predetermined or the match is presented as a non-interactive cutscene. The engine provides the result without requiring player input. | Prologue loss to Murchadh (Chapter 0) |

In Scripted mode, the engine may either replay a predetermined sequence of moves or simply emit the result directly. The Campaign System decides which mode to use; the Board Rules Engine executes it.

#### 10. Side Assignment

In each match, the Campaign System (or quick play menu) tells the engine which side the player controls. The concept implies the player may play as either Attacker or Defender depending on the match — the engine supports both.

### States and Transitions

| State | Entry Condition | Behavior | Exit Condition |
|-------|----------------|----------|----------------|
| **Idle** | Engine initialized, no match active | Waiting for match start request | `start_match()` called |
| **Setup** | Match start requested | Place pieces in starting layout, set active side to Attackers, set match mode (Standard/Scripted) | Board populated, ready for first turn |
| **Awaiting Move** | Turn begins | Generate legal moves for active side. If no legal moves exist, transition to Resolved. Otherwise wait for move input (from player via UI, or from AI System). | Valid move received, or no legal moves detected |
| **Processing Move** | Valid move submitted | Move piece, check for captures (remove captured pieces), check win conditions | Move fully resolved |
| **Resolved** | Win condition met or no legal moves | Record result (winner, reason, move count, pieces remaining). Emit `match_ended` signal. | Campaign System or UI acknowledges result |

**Turn cycle:** Awaiting Move → Processing Move → Awaiting Move (other side) → ...

**Scripted mode:** Setup → Resolved (skips the turn cycle entirely, result is predetermined).

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **AI System** | AI consumes Board Rules Engine | AI calls `get_legal_moves(side)` to get available moves, reads board state to evaluate positions, submits chosen move via `submit_move(from, to)` |
| **Board UI** | UI consumes Board Rules Engine | UI reads board state for rendering, calls `get_legal_moves(piece)` to show valid destinations on tap, submits player move via `submit_move(from, to)`. Listens to signals: `piece_moved`, `piece_captured`, `match_ended` |
| **Campaign System** | Campaign drives Board Rules Engine | Campaign calls `start_match(mode, side_assignment)` to begin a match. Listens to `match_ended` signal to receive result (winner, move count, pieces remaining). Provides match mode (Standard/Scripted). |
| **Tutorial System** | Tutorial consumes Board Rules Engine | Tutorial may constrain legal moves (e.g., highlight only the "correct" move during a guided lesson). Reads board state and listens to all signals. |
| **Audio System** | Audio listens to Board Rules Engine | Listens to signals: `piece_moved`, `piece_captured`, `king_threatened`, `match_ended` to trigger SFX |

**Signals emitted by the Board Rules Engine:**

| Signal | Data | When |
|--------|------|------|
| `piece_moved` | piece, from_pos, to_pos | After a piece is moved |
| `piece_captured` | piece, position, captured_by | After a piece is removed |
| `turn_changed` | new_active_side | After move processing completes |
| `match_ended` | winner, reason, move_count, pieces_remaining | When a win condition is met |
| `king_threatened` | king_pos, threat_count | When the King has 2+ adjacent attackers (informational, for UI/audio) |

The Board Rules Engine never calls into other systems — it only emits signals. Other systems subscribe and react. This keeps the engine a pure rules layer with no upstream dependencies.

## Formulas

### Legal Move Generation

```
legal_moves(piece) = for each direction in [up, down, left, right]:
    walk from piece position one cell at a time
    stop when hitting: board edge, occupied cell, or restricted tile (if not King)
    each empty cell visited is a legal destination
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| piece | Piece | any active piece | The piece to generate moves for |
| direction | Vector2i | (0,1), (0,-1), (1,0), (-1,0) | The four orthogonal directions |

**Output:** Array of valid destination positions. Empty array = piece is blocked.

### Capture Detection

```
after_move(piece, destination):
    for each axis [horizontal, vertical]:
        for each direction on that axis [+, -]:
            check the adjacent cell in that direction
            if it contains an enemy piece:
                check the cell on the opposite side of that enemy
                if it contains a friendly piece OR is a hostile tile:
                    enemy piece is captured
```

**Note:** The moved piece is always one of the flanking pieces. Only check from the moved piece's new position.

### King Capture Detection

```
king_is_captured =
    count occupied orthogonal neighbours of King that are:
        enemy pieces OR hostile tiles (empty Throne, Corners)
    if count == 4: King is captured
```

### King Threat Level

```
king_threat = count of orthogonally adjacent Attacker pieces (0–4)
emit king_threatened when king_threat >= 2
```

This is informational only — used by UI and Audio for tension feedback, not for rules.

This system has no balancing formulas — that complexity lives in the AI System (difficulty, personality).

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|-------------------|-----------|
| Piece moves into a sandwich voluntarily | No capture occurs | Capture is active only — the moving player must close the trap |
| Single move causes captures on two different axes | Both captures occur simultaneously | Multi-capture rewards clever positioning |
| King is on the Throne and surrounded on 3 sides | King is NOT captured — Throne is only hostile when empty | King occupying the Throne means it's not an empty hostile tile |
| King moves off Throne, enemy is adjacent to now-empty Throne | The adjacent enemy is not captured by the Throne alone — capture requires an active move closing the sandwich | Hostile tiles don't actively capture; they only assist |
| Attacker moves next to Corner tile with enemy between | Enemy is captured (Corner acts as hostile flanking piece) | Corners are always hostile regardless of King position |
| All Defenders are captured but King remains | Game continues — King can still attempt to reach a corner | Only King capture or corner escape ends the game |
| King is adjacent to a corner with one attacker blocking | King must move around — no special rules apply | Movement rules are consistent for all pieces |
| Player has pieces but none can move (all blocked) | Player loses — "no legal moves" win condition | Stalemate is a loss, not a draw |
| King reaches corner on the same move that would result in a capture of another defender | King reaching corner takes priority — Defenders win immediately | Win condition is checked before processing other captures |
| Both sides could claim victory on the same move | Not possible — only one side moves per turn, and win conditions are checked after that side's move | Turn structure prevents simultaneous wins |
| King is surrounded on 3 sides by attackers and 1 side by a defender | King is NOT captured — the defender is friendly | All 4 adjacent cells must be hostile (enemy or hostile tile) |
| Scripted match — player attempts input | Input is ignored or not presented; the match plays as a cutscene | Campaign System sets the mode; UI respects it |

## Dependencies

| System | Direction | Nature | Interface |
|--------|-----------|--------|-----------|
| **AI System** | Depends on this | Hard — AI cannot function without board state and legal moves | `get_board_state()`, `get_legal_moves(side)`, `submit_move(from, to)` |
| **Board UI** | Depends on this | Hard — UI renders board state and relays player input | `get_board_state()`, `get_legal_moves(piece)`, `submit_move(from, to)`, all signals |
| **Campaign System** | Depends on this | Hard — campaign runs matches through this engine | `start_match(mode, side_assignment)`, `match_ended` signal |
| **Tutorial System** | Depends on this | Hard — tutorial teaches rules using the engine | `get_legal_moves(piece)`, all signals |
| **Audio System** | Depends on this | Soft — audio enhances the experience but the game functions without it | `piece_moved`, `piece_captured`, `king_threatened`, `match_ended` signals |

**This system depends on:** Nothing. It is a pure foundation layer with zero upstream dependencies.

**Bidirectional note:** When the AI System, Campaign System, Board UI, Tutorial System, and Audio System GDDs are written, each must list Board Rules Engine as a dependency and reference the signals/methods defined here.

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|--------------------|--------------------|
| `board_size` | 7 | 7 (fixed) | N/A — changing board size would require new starting layouts and rebalancing | N/A |
| `attacker_count` | 16 | 12–20 | More attackers = harder for defenders, easier king enclosure | Fewer attackers = easier for defenders to escape |
| `defender_count` | 8 | 4–10 | More defenders = easier to protect king, more blocking options | Fewer defenders = king exposed earlier |
| `king_capture_sides` | 4 | 3–4 | N/A (4 is maximum) | 3 = significantly easier for attackers, changes game balance fundamentally |
| `king_threatened_threshold` | 2 | 1–3 | Higher = fewer threat warnings, less UI tension feedback | Lower = more frequent warnings, may feel spammy |

**Note:** Most of these values should remain fixed for Fidchell — they define the game's identity. They are externalized as data rather than hardcoded so that playtesting can experiment, but the default values are the designed values. The real tuning lives in the AI System (difficulty, personality), not here.

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Piece moved | Piece slides from origin to destination (not instant) | Soft stone-on-wood slide sound | High |
| Piece captured | Captured piece fades or sinks; brief impact flash | Stone clack — satisfying, weighty | High |
| King threatened (2+ adjacent attackers) | Subtle pulse or glow on King; threatened direction indicators | Low tension tone or heartbeat | Medium |
| King escapes to corner | Board-wide flash or light sweep from corner | Triumphant Celtic sting — horn or harp swell | High |
| King captured | Board darkens; King surrounded pieces glow | Low drone, finality — match over | High |
| No legal moves (stalemate loss) | Dim all pieces for losing side | Quiet defeat tone | Medium |
| Turn change | Subtle highlight shift to active side's pieces | None (would be repetitive) | Low |
| Multi-capture | Each capture plays sequentially with slight delay for readability | Cascading capture sounds — satisfying chain | Medium |

**Note:** The Board Rules Engine emits signals; the Board UI and Audio System implement the actual feedback. This table defines what events need feedback, not how it's rendered.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|-----------------|-----------|
| Board state (all pieces) | Centre of screen | Every move | Always during match |
| Active side indicator | Top or bottom edge | Every turn | Always during match |
| Legal move highlights | On board tiles | On piece selection | When player taps a friendly piece |
| Last move indicator | On board (from/to cells) | Every move | After first move |
| Captured pieces count | Side panel or match border | On capture | Always during match |
| Match result | Overlay | On match end | When win condition met |
| Move count | Subtle counter | Every move | Optional — feeds into reputation bonus |

**Note:** Detailed UI layout, touch interaction patterns, and responsive scaling are owned by the Board UI GDD.

## Acceptance Criteria

- [ ] Board initializes with correct starting layout (16 attackers, 8 defenders, King on Throne)
- [ ] All pieces move orthogonally any number of squares, blocked by other pieces and board edges
- [ ] Non-King pieces cannot enter Throne or Corner tiles
- [ ] King can enter Throne and all four Corner tiles
- [ ] Custodial capture works: moving a piece to flank an enemy removes the enemy
- [ ] Voluntary entry into a sandwich does NOT trigger capture
- [ ] Multi-capture works: a single move can capture multiple pieces on different axes
- [ ] Corner tiles and empty Throne act as hostile for capture purposes
- [ ] King requires 4-sided enclosure to capture (enemy pieces or hostile tiles)
- [ ] King on Throne is NOT captured at 3 sides (Throne is not hostile while occupied)
- [ ] Defender wins immediately when King reaches any corner
- [ ] Attacker wins immediately when King is fully surrounded
- [ ] Player with no legal moves loses
- [ ] Win condition check halts the game immediately — no further moves processed
- [ ] `get_legal_moves()` returns correct moves for every board state tested
- [ ] All signals emit with correct data (piece_moved, piece_captured, turn_changed, match_ended, king_threatened)
- [ ] Scripted mode skips gameplay and emits predetermined result
- [ ] Side assignment works for both player-as-attacker and player-as-defender
- [ ] No hardcoded values — all constants defined in external data
- [ ] Legal move generation completes within 1ms on target mobile hardware

## Open Questions

| Question | Owner | Target Resolution | Resolution |
|----------|-------|-------------------|-----------|
| Does the player always play as Defender, always as Attacker, or does it vary by match? The concept implies a fixed side but doesn't state which. | Game Designer | Campaign System GDD | — |
| Should the engine support undo/redo for casual play? Could help mobile accessibility but may conflict with AI timing. | Game Designer | Board UI GDD | — |
| Is there a draw condition (e.g., repeated board states, move limit) or can matches theoretically last forever? | Game Designer | Before implementation | — |
| Should the Prologue scripted loss show a real board with moves playing out, or a purely narrative cutscene with no board? | Creative Director | Campaign System GDD | — |
