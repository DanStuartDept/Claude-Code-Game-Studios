# Board UI

> **Status**: Designed
> **Author**: user + game-designer
> **Last Updated**: 2026-03-28
> **Implements Pillar**: Core gameplay — the player's window into the board

## Overview

Board UI is the match screen — the player's direct interface to the Fidchell board. It renders the 7×7 grid, all pieces, tile highlights, and match information. It translates touch input into game actions: tap a piece to select it, see legal moves highlighted, tap a destination to move. It listens to Board Rules Engine signals to animate piece movement, captures, and win/loss outcomes. The Board UI is a consumer — it reads board state and relays player input, but owns no game logic. It is loaded as the `match` base scene by Scene Management and must adapt to varying mobile screen sizes and aspect ratios while keeping the board readable and pieces tappable.

## Player Fantasy

The board should feel like a physical object — carved wood, polished stone pieces, warm lamplight. Tapping a piece should feel like picking it up; seeing legal moves should feel like reading the board's possibilities at a glance. Captures should be visceral — the trapped piece doesn't just disappear, it's taken. The player should feel the weight of the King's position, the tightening net of attackers, the tension of an escape route narrowing. On mobile, the board should feel natural under the thumb — not too small, not too cramped. The player should never fight the interface to play the game. Touch the piece, see the options, make the choice. The board is the game's heart and it should feel like it.

## Detailed Design

### Core Rules

#### 1. Board Layout

The board is rendered as a square grid centred on the screen. The grid occupies the maximum square area that fits the screen's narrowest dimension, with margins for match info above and below.

| Element | Visual Treatment |
|---------|-----------------|
| **Normal tiles** | Hand-painted wood surface in the style of late-90s LucasArts adventure games — lush painterly detail, deep rich shadows, bold ink outlines |
| **Throne tile** | Centre cell — distinct Celtic knotwork carving, visually elevated with warm golden highlights |
| **Corner tiles** | Four corners — marked with Celtic escape symbolism, painted with richer detail than normal tiles |
| **Grid lines** | Thin ink lines — visible but not dominant, consistent with the hand-drawn style |
| **Environment** | Board sits on an illustrated surface (tavern table, cliff-edge stone, court hall) that changes per campaign chapter. Warm saturated palette, deep rich shadows. |

**Orientation:** Board is always displayed with the same orientation regardless of which side the player controls. Player's pieces are not rotated to the bottom — the board is a fixed object.

#### 2. Pieces

| Piece | Visual | Size |
|-------|--------|------|
| **Attacker** | Dark, rough-hewn stones with bold ink outlines — subtle menacing faces or shapes in the caricature style | Standard (fits within cell with padding) |
| **Defender** | Lighter, smoother stones with bold ink outlines — protective symbolism, warmer tones | Standard |
| **King** | Larger light stone with gold band and slightly regal bearing — characterful, not realistic | Slightly larger than standard, visually distinct |

All pieces are hand-drawn with bold ink outlines and slight caricature exaggeration, consistent with the LucasArts adventure game art direction. Pieces must be visually distinguishable at a glance. Colour alone is not sufficient — shape or marking must differentiate Attackers from Defenders for colourblind accessibility.

#### 3. Touch Input — Tap-Tap (Primary)

The primary input method is tap-to-select, tap-to-move:

```
1. Player taps a friendly piece
   → Piece visually lifts or highlights (selected state)
   → Legal move destinations highlight on the board
   → Previously selected piece (if any) deselects

2. Player taps a highlighted destination
   → Submit move to Board Rules Engine via submit_move(from, to)
   → Piece animates from origin to destination
   → Selected state clears

3. Player taps a non-highlighted cell or empty space
   → Deselect current piece, clear highlights

4. Player taps a different friendly piece
   → Switch selection to the new piece, update highlights

5. Player taps the already-selected piece
   → Deselect it, clear highlights
```

#### 4. Touch Input — Drag (Secondary)

Drag is supported as an alternative for players who prefer it:

```
1. Player touches and holds a friendly piece (150ms hold threshold)
   → Piece visually lifts and follows the finger
   → Legal move destinations highlight on the board
   → Piece is rendered above other elements (no z-fighting)

2. Player drags to a highlighted destination and releases
   → Submit move to Board Rules Engine
   → Piece animates to snap into the cell

3. Player drags to a non-highlighted cell and releases
   → Piece animates back to its original position (cancelled)

4. Player drags off the board edge and releases
   → Piece animates back to its original position (cancelled)
```

**Finger offset:** While dragging, render the piece slightly above the touch point so the player can see where they're placing it. The piece should not be hidden under the finger.

#### 5. Legal Move Highlights

When a piece is selected, all legal destination cells are highlighted:

| Highlight Type | Visual | Meaning |
|---------------|--------|---------|
| **Move destination** | Subtle glow or dot on the cell | The piece can move here |
| **Capture move** | Stronger highlight, possibly with an indicator on the enemy piece that would be captured | Moving here captures an enemy piece |
| **King escape** | Distinct highlight on corner tile (gold glow) | King can reach a corner — victory move |

Highlights must be visible but not overwhelming. The board should still be readable.

#### 6. Move Animation

All piece movement is animated, never instant:

| Animation | Duration | Easing |
|-----------|----------|--------|
| **Piece move** | 0.25s | Ease-out (decelerates into position) |
| **Piece capture (removal)** | 0.3s | Fade + sink or shatter — piece visually leaves the board |
| **Multi-capture** | 0.3s per capture, sequential with 0.1s gap | Each capture plays in sequence for readability |
| **Drag snap** | 0.1s | Quick snap into grid cell |
| **Drag cancel** | 0.15s | Piece returns to origin |

Input is blocked during move animation — the player cannot select another piece until the current move resolves.

#### 7. Match Information Display

| Element | Position | Content |
|---------|----------|---------|
| **Opponent info** | Top of screen | Opponent name, portrait, captured piece count |
| **Player info** | Bottom of screen | Player label, captured piece count |
| **Turn indicator** | Between board and active player's info area | Subtle glow or arrow indicating whose turn it is |
| **Move counter** | Small, unobtrusive corner | Total moves played (feeds into reputation bonus) |
| **Last move indicator** | On board | Origin cell dimmed, destination cell subtly marked — shows what the opponent just did |

#### 8. Match Result Display

When the Board Rules Engine emits `match_ended`:

1. Brief pause (0.5s) — let the final move settle
2. Board dims slightly
3. Result overlay fades in via Scene Management (`push_overlay("match_result")`)
4. Display: Win/Loss, reason (King escaped / King captured / no moves), move count, reputation earned

#### 9. Responsive Scaling

The board must work on screens from 4.7" phones to 12.9" tablets:

| Screen Size | Adaptation |
|------------|------------|
| **Small phone (< 5.5")** | Board fills width with minimal margins. Piece tap targets are at least 44pt (Apple HIG minimum). Match info compact. |
| **Large phone (5.5"–6.7")** | Board fills width with comfortable margins. Standard layout. |
| **Tablet (7"+)** | Board does not stretch to fill — caps at a maximum size. Extra space used for larger margins and more detailed match info. |

**Minimum tap target:** Each cell must be at least 44×44 points on screen. On a 7×7 grid, this means the board needs at least 308×308 points — achievable on all modern phones.

#### 10. Pause Access

A pause button is always visible during a match (top corner, small icon). Tapping it calls `push_overlay("pause")` via Scene Management. The match scene remains loaded underneath.

### States and Transitions

| State | Entry Condition | Behavior | Exit Condition |
|-------|----------------|----------|----------------|
| **Loading** | Match scene loaded by Scene Management | Build board visuals, place pieces per Board Rules Engine starting layout | Board rendered, ready for input |
| **Player Turn — Idle** | Player's turn, no piece selected | Awaiting tap on a friendly piece. Enemy pieces and empty cells are non-interactive. | Player taps a friendly piece |
| **Player Turn — Selected** | Player tapped a friendly piece | Show legal move highlights. Accept: tap destination (move), tap other piece (reselect), tap empty (deselect), begin drag (drag mode). | Move submitted, piece deselected, or drag started |
| **Player Turn — Dragging** | Player hold-dragged a piece | Piece follows finger, highlights shown. Accept: release on valid cell (move), release elsewhere (cancel). | Move submitted or drag cancelled |
| **Animating** | Move submitted or Board Rules Engine signal received | Playing move/capture/result animation. All input blocked. | Animation completes |
| **AI Turn** | Board Rules Engine signals `turn_changed` to AI side | Input blocked for player pieces. Opponent thinking indicator shown. Waiting for AI move signal. | `piece_moved` signal received from Board Rules Engine |
| **Match Over** | `match_ended` signal received | Play result animation, then push match result overlay | Player dismisses result overlay |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Board Rules Engine** | Board UI consumes | Reads `get_board_state()` for rendering. Calls `get_legal_moves(piece)` on piece selection. Calls `submit_move(from, to)` on player move. Listens to signals: `piece_moved`, `piece_captured`, `turn_changed`, `match_ended`, `king_threatened`. |
| **Scene Management** | Scene Management loads Board UI | Board UI is the `match` base scene. Calls `push_overlay("pause")` for pause menu. Receives `push_overlay("match_result")` from Campaign System. |
| **AI System** | No direct interaction | AI moves arrive via Board Rules Engine signals. Board UI animates them identically to player moves. |
| **Campaign System** | Campaign provides match context | Campaign provides opponent name, portrait, and side assignment before match loads. Board UI displays this info. |
| **Tutorial System** | Tutorial may constrain Board UI | Tutorial may limit which pieces are tappable or override highlights to guide the player to a specific move. |
| **Audio System** | No direct interaction | Audio listens to Board Rules Engine signals independently. Board UI does not trigger audio. |

## Formulas

### Board Scaling

```
cell_size = min(screen_width, screen_height - ui_margin) / board_size
cell_size = max(cell_size, min_tap_target)
board_pixel_size = cell_size * board_size
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `screen_width` | float | 320–1024pt | Device | Logical screen width in points |
| `screen_height` | float | 568–1366pt | Device | Logical screen height in points |
| `ui_margin` | float | 80–160pt | Config | Space reserved for match info above and below board |
| `board_size` | int | 7 | Board Rules Engine | Grid dimension |
| `min_tap_target` | float | 44pt | Config (Apple HIG) | Minimum tappable cell size |

**Expected cell size range:** 44pt (small phone) to ~100pt (tablet, capped)

### Touch Hit Detection

```
tapped_cell = floor((touch_position - board_origin) / cell_size)
valid = tapped_cell.x >= 0 AND tapped_cell.x < 7
    AND tapped_cell.y >= 0 AND tapped_cell.y < 7
```

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|-------------------|-----------|
| Player taps during move animation | Input is queued or ignored — no mid-animation actions | Prevents desync between visual state and board state |
| Player taps an enemy piece | No response — only friendly pieces are selectable | Clear feedback: only your pieces respond to touch |
| Player rapidly double-taps a piece | First tap selects, second tap deselects. No accidental moves. | Debounce-safe — selection toggle is predictable |
| Drag starts but player's finger drifts to an enemy piece | Piece follows finger but destination is invalid — releasing cancels the drag | Drag only completes on highlighted cells |
| Screen rotates during match | Lock to portrait orientation. No rotation handling needed. | Mobile board games are best in portrait; simplifies layout |
| Very small screen (< 4.7") | Board still renders at 44pt minimum cell size. Match info may truncate or use icons instead of text. | Accessibility minimum is non-negotiable |
| Player has no legal moves (stalemate) | No pieces respond to tap — all pieces appear dimmed. Match ends via Board Rules Engine. | The UI reflects the rules engine's state |
| Multi-capture animation — player taps during sequence | Input blocked until all captures animate | Each capture must be visible for the player to understand what happened |
| AI move happens while player is examining the board | AI move animates normally. If player had a piece selected, selection clears. | AI turn starts fresh — no stale selections |
| King threatened — visual feedback | King piece pulses or glows. Subtle directional indicators show which sides have adjacent attackers. | Board Rules Engine's `king_threatened` signal drives this |

## Dependencies

| System | Direction | Nature | Interface |
|--------|-----------|--------|-----------|
| **Board Rules Engine** | This depends on | Hard — Board UI cannot function without board state, legal moves, and signals | All public methods and signals defined in Board Rules Engine GDD |
| **Scene Management** | This depends on | Hard — Board UI is loaded as the `match` scene | `change_scene("match")`, `push_overlay()` |
| **Tutorial System** | Depends on this | Soft — tutorial constrains Board UI input and highlights | Tutorial provides: allowed pieces, forced highlights |
| **Campaign System** | Provides context | Soft — campaign provides opponent info for display | Opponent name, portrait, side assignment |

**This system depends on:** Board Rules Engine (hard), Scene Management (hard).

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|--------------------|--------------------|
| `move_anim_duration` | 0.25s | 0.1–0.5s | Moves feel weighty, deliberate | Moves feel snappy, responsive |
| `capture_anim_duration` | 0.3s | 0.15–0.6s | Captures feel dramatic | Captures feel quick |
| `drag_hold_threshold` | 150ms | 80–300ms | More deliberate drag start (fewer accidental drags) | Faster drag entry (more accidental drags) |
| `min_tap_target` | 44pt | 38–56pt | Larger cells, fewer fit on screen | Smaller cells, risk of mistaps |
| `ui_margin` | 120pt | 80–160pt | More space for match info, smaller board | Larger board, less info space |
| `result_pause_before_overlay` | 0.5s | 0.2–1.0s | More time to absorb the final move | Faster result display |
| `last_move_highlight_opacity` | 0.3 | 0.1–0.6 | Last move more visible | Last move more subtle |
| `king_threat_pulse_speed` | 1.0s cycle | 0.5–2.0s | Faster pulse, more urgency | Slower pulse, calmer |

## Acceptance Criteria

- [ ] Board renders correctly on small phone (4.7"), large phone (6.7"), and tablet (10"+)
- [ ] All cells meet 44pt minimum tap target on smallest supported device
- [ ] Tap-to-select highlights all legal moves correctly (cross-verified with Board Rules Engine)
- [ ] Tap-to-move submits the correct move and animates the piece
- [ ] Drag-to-move works: piece follows finger, snaps to valid cell, cancels on invalid release
- [ ] Capture animation plays for each captured piece, sequentially for multi-captures
- [ ] King escape move shows distinct highlight on corner tiles
- [ ] Capture moves show distinct highlight indicating which enemy will be taken
- [ ] Input is blocked during all animations
- [ ] AI moves animate identically to player moves
- [ ] Opponent thinking indicator displays during AI turn
- [ ] Turn indicator correctly reflects whose turn it is
- [ ] Last move indicator shows the previous move on the board
- [ ] King threat visual feedback triggers when `king_threatened` signal fires
- [ ] Pause button is always accessible and pushes pause overlay
- [ ] Match result overlay displays after win/loss with correct information
- [ ] Portrait orientation locked — no rotation handling needed
- [ ] Pieces are distinguishable without colour (shape/marking for colourblind accessibility)
- [ ] Art style consistent with hand-drawn LucasArts adventure game direction
- [ ] No hardcoded values — all visual parameters in external config
- [ ] Animations run at 60fps on target mobile hardware

## Open Questions

| Question | Owner | Target Resolution | Resolution |
|----------|-------|-------------------|-----------|
| Should the board support pinch-to-zoom on small screens, or is fixed scaling sufficient? | UX Designer | Prototyping | — |
| Should captured pieces be displayed in a "graveyard" area alongside the board, or just as a count? | Art Director | Visual design phase | — |
| Should there be a move history view (scrollable list of past moves) or is last-move indicator enough? | Game Designer | Playtesting | — |
| Art style is defined (hand-drawn cel animation, LucasArts Curse of Monkey Island era). How much environment context surrounds the board per match — full scene illustration vs. vignette vs. board only? | Art Director | Visual design phase | — |
