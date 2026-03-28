# Tutorial System

> **Status**: Designed
> **Author**: user + game-designer
> **Last Updated**: 2026-03-28
> **Implements Pillar**: Accessibility — teaching the game without breaking the fiction

## Overview

The Tutorial System runs during the Prologue's first match, teaching the player how to play Fidchell through a guided, scripted encounter. It constrains Board UI input to allow only specific pieces and moves at each step, uses narrator-voice text (via the Dialogue System) to explain rules as they become relevant, and scripts the AI opponent's moves to create teachable moments — a capture opportunity, a threat to the King, and a King escape to the corner. The tutorial is not a separate mode or screen — it is a real match on the real board, played with training wheels. The system activates when the Campaign System begins the Prologue tutorial match and deactivates when the scripted sequence completes. It does not persist — once the Prologue is complete, the Tutorial System is never invoked again.

## Player Fantasy

The player should feel like they're learning by doing, not reading a manual. The narrator's voice is calm and spare — "Move this piece here. Watch what happens." — not a textbook. Each concept is introduced the moment it matters: custodial capture is explained when a capture is about to happen, not three screens before. The board is real, the pieces are real, the moves are real — the tutorial just narrows the world so the player can focus on one thing at a time. By the end, the player should feel ready to play a real match, not like they just graduated from a classroom. The tutorial should feel like a friend showing you the game, not an app onboarding you.

## Detailed Design

### Core Rules

#### 1. Tutorial Structure — Step Sequence

The tutorial is a linear sequence of steps. Each step has: a narrator line, an input constraint (which pieces/moves are allowed), and a scripted AI response. The player cannot deviate from the sequence — the tutorial controls the board.

| Step | Concept Taught | Narrator Text (draft) | Player Action | AI Response |
|------|---------------|----------------------|---------------|-------------|
| 1 | Introduction | "The board is set. You are the Defender — your pieces are the light stones. The tall one in the centre is the King." | None — tap to continue | — |
| 2 | Movement | "Pieces move in straight lines — up, down, left, right. As far as the path is clear. Tap the piece I've marked, then tap where you'd like it to go." | Move one highlighted Defender to one of 2–3 highlighted destinations | AI moves an Attacker (scripted, non-threatening) |
| 3 | Restricted tiles | "The centre square — the Throne — and the four corners are special. Only the King may enter them." | Move a Defender (highlight avoids Throne/corners to reinforce the rule) | AI moves to set up a capture opportunity |
| 4 | Custodial capture | "When you trap an enemy piece between two of yours, it is taken. Move here — watch." | Move the highlighted Defender to complete a custodial capture | Capture animates. AI moves (scripted) |
| 5 | Being captured | "But your pieces can be trapped the same way. Be careful where you leave them." | AI captures one of the player's Defenders (scripted). Narrator: "Like that." | — (AI acted, player observes) |
| 6 | The King's importance | "The King must escape to any corner of the board. That is how you win. But if the enemy surrounds him on all four sides, you lose." | None — tap to continue | AI moves to threaten the King (scripted, not actually surrounding) |
| 7 | King escape | "The path is open. Move the King to the corner." | Move the King to a highlighted corner tile | — |
| 8 | Victory | "The King has escaped. You win." | Match ends — Board Rules Engine processes King escape victory | — |

Total: ~8 steps, approximately 2–3 minutes of play.

#### 2. Input Constraints

During each step, the Tutorial System tells Board UI which pieces are tappable and which destinations are valid:

- `set_allowed_pieces([piece_ids])` — only these pieces respond to tap/drag
- `set_forced_highlights([cell_positions])` — override legal move highlights to show only tutorial-approved destinations
- All other pieces appear dimmed (same as Board UI's "upcoming" treatment)

When no constraint is active (between steps), input is fully blocked until the next narrator line is dismissed.

#### 3. Scripted AI Moves

The AI System is not used during the tutorial. Instead, the Tutorial System provides pre-defined moves for each AI turn:

- Tutorial calls `Board Rules Engine.submit_move(from, to)` directly for AI moves
- Board UI animates these moves identically to normal AI moves
- The AI "opponent" for the tutorial has no profile — it's a faceless practice partner (no portrait, no name, narrator handles all text)

#### 4. Narrator Integration

Tutorial text uses the Dialogue System's narrator presentation (no portrait, italic/centred text). Lines are tagged:

```
{
  "opponent_id": "narrator",
  "timing": "tutorial",
  "tutorial_step": 1,
  "text": "The board is set. You are the Defender..."
}
```

The player taps to advance narrator text (same as standard dialogue — tap to advance, no auto-advance).

#### 5. No Skip Option

The tutorial cannot be skipped on first play. It is the Prologue's first match — skipping it would break the campaign flow. The Prologue itself is not replayable, so the tutorial only runs once per campaign.

#### 6. Tutorial Board State

The tutorial does not use the standard starting layout. It uses a simplified board state with fewer pieces to reduce visual noise and ensure the scripted sequence works:

- Fewer Attackers (8–10 instead of 16)
- Fewer Defenders (4–5 instead of 8)
- King on the Throne
- Pieces positioned to enable the step sequence (capture opportunity, King escape path)

The exact starting layout is defined in the tutorial data file, not in Board Rules Engine config.

### States and Transitions

| State | Entry Condition | Behavior | Exit Condition |
|-------|----------------|----------|----------------|
| **Inactive** | Default — tutorial not running | System idle. No constraints on Board UI. | Campaign System activates tutorial for Prologue match 1 |
| **Step Active** | Tutorial step loaded | Display narrator text. Wait for player to dismiss. Apply input constraints for this step's player action (if any). | Player completes the required action, or tap-to-continue if no action |
| **Awaiting Player Move** | Narrator text dismissed, player action required | Board UI shows only allowed pieces and forced highlights. Player must make the guided move. | Player submits the correct move via Board UI |
| **AI Turn** | Player move completed, scripted AI response defined | Tutorial submits the scripted AI move to Board Rules Engine. Board UI animates it. | AI move animation completes |
| **Complete** | Final step (King escape victory) processed | Remove all input constraints. Notify Campaign System that tutorial match is complete. | Campaign System proceeds to Prologue match 2 (scripted Murchadh loss) |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Board Rules Engine** | Tutorial drives scripted moves | Tutorial calls `submit_move(from, to)` for scripted AI moves. Board Rules Engine processes them normally (validates, emits signals). Tutorial also calls `setup_board(tutorial_layout)` to load the simplified starting position. |
| **Board UI** | Tutorial constrains input | Tutorial calls `set_allowed_pieces([ids])` and `set_forced_highlights([cells])` to limit player interaction. Board UI renders constrained state (dimmed pieces, guided highlights). Tutorial calls `clear_constraints()` when done. |
| **Dialogue System** | Tutorial uses narrator voice | Tutorial requests narrator lines tagged with `timing: "tutorial"` and `tutorial_step: N`. Dialogue System displays them in narrator presentation. Tutorial waits for `dialogue_complete` before proceeding. |
| **Campaign System** | Campaign activates tutorial | Campaign System calls `Tutorial.activate()` when Prologue match 1 begins. Tutorial emits `tutorial_complete` when the scripted match ends. Campaign then proceeds to match 2. |
| **AI System** | No interaction | AI System is bypassed during tutorial. Tutorial provides all AI moves directly. |

## Formulas

No mathematical formulas. The Tutorial System is a linear step sequence with scripted moves — no calculations. All positions, moves, and constraints are defined in the tutorial data file.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|-------------------|-----------|
| Player taps a non-allowed piece during a guided step | No response — piece is dimmed. Only allowed pieces respond to input. | Tutorial constrains input to prevent confusion |
| Player taps an allowed piece but then taps a non-highlighted destination | Deselects the piece, clears highlights (same as Board UI normal behavior). Player must tap the piece again and choose a valid destination. | Consistent with Board UI — no special tutorial exception needed |
| Player drags an allowed piece to an invalid cell | Piece returns to origin (same as Board UI drag cancel). | Standard Board UI behavior applies |
| Player backgrounds the app mid-tutorial | Tutorial state is not saved (Prologue is not replayable mid-match). On return, the match resumes from the current step if the app wasn't killed. If killed, the Prologue restarts from the beginning on next launch. | Tutorial is short enough (~3 minutes) that restarting is acceptable |
| Player has already played Fidchell and finds the tutorial tedious | Tutorial cannot be skipped on first play. It's ~8 steps and 2–3 minutes. The narrator tone is spare, not condescending. | Keeping it short is the mitigation — no skip button |
| Board Rules Engine rejects a scripted AI move | Should never happen — tutorial moves are pre-validated against the tutorial layout. If it does, log an error and skip to the next step. | Defensive programming — tutorial should never stall |
| Tutorial narrator line has no matching entry in Dialogue database | Fall back to a generic narrator line. Log a warning. | Same fallback as standard Dialogue System |
| Player completes the tutorial King escape but Board Rules Engine doesn't emit `match_ended` | Should never happen — King on corner always triggers victory. If it does, Tutorial forces completion and emits `tutorial_complete`. | Tutorial must always complete cleanly |
| New Game after completing the campaign — does tutorial replay? | Yes. New Game resets everything. The Prologue runs from the start, including the tutorial. | Clean slate means full replay |

## Dependencies

| System | Direction | Nature | Interface |
|--------|-----------|--------|-----------|
| **Board Rules Engine** | This depends on | Hard — Tutorial submits moves and reads board state | `submit_move()`, `setup_board()`, `match_ended` signal |
| **Board UI** | This depends on | Hard — Tutorial constrains input and highlights | `set_allowed_pieces()`, `set_forced_highlights()`, `clear_constraints()` |
| **Dialogue System** | This depends on | Soft — Tutorial uses narrator presentation for instructional text | Narrator lines tagged with `timing: "tutorial"` |
| **Campaign System** | Depends on this | Soft — Campaign activates tutorial and waits for completion | `Tutorial.activate()`, `tutorial_complete` signal |

**This system depends on:** Board Rules Engine (hard), Board UI (hard), Dialogue System (soft).

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|--------------------|--------------------|
| `tutorial_step_count` | 8 | 5–12 | More concepts taught, longer tutorial | Fewer concepts, faster but less thorough |
| `tutorial_piece_count_attackers` | 8–10 | 6–16 | More realistic board, potentially confusing | Cleaner board, easier to focus |
| `tutorial_piece_count_defenders` | 4–5 | 3–8 | More pieces to manage during learning | Simpler board state |
| `allow_free_play_after_tutorial` | false | true/false | Player can explore the board after the guided sequence | Tutorial ends immediately after King escape |
| `narrator_line_delay` | 0.0s | 0.0–0.5s | Brief pause before narrator text appears | Instant narrator text |

## Acceptance Criteria

- [ ] Tutorial activates only during Prologue match 1
- [ ] Simplified board layout loads correctly (fewer pieces than standard)
- [ ] Each tutorial step displays narrator text in narrator presentation style
- [ ] Player can only interact with allowed pieces during guided steps
- [ ] Forced highlights override standard legal move highlights
- [ ] Non-allowed pieces appear dimmed
- [ ] Scripted AI moves animate identically to normal AI moves
- [ ] Custodial capture is demonstrated (player captures an enemy piece in step 4)
- [ ] Player's piece being captured is demonstrated (AI captures in step 5)
- [ ] King escape to corner completes the tutorial match
- [ ] Board Rules Engine emits `match_ended` on King escape — tutorial handles it
- [ ] `tutorial_complete` signal fires after the final step
- [ ] Campaign System proceeds to Prologue match 2 after tutorial completes
- [ ] Tutorial cannot be skipped
- [ ] Tutorial does not use the AI System — all AI moves are scripted
- [ ] All tutorial data (steps, moves, layouts, narrator text) loaded from external data file
- [ ] Tutorial completes in under 3 minutes of player time

## Open Questions

| Question | Owner | Target Resolution | Resolution |
|----------|-------|-------------------|-----------|
| Should the tutorial teach the King's special capture rule (4-sided enclosure), or just mention it in narrator text and let the player discover it in play? | Game Designer | Playtesting | — |
| Should there be a "reminder" system that re-explains rules if the player loses 3+ times to the same opponent in Chapter 1? Not a full tutorial replay, but contextual hints. | UX Designer | Playtesting | — |
| Should the tutorial opponent have a name/portrait (a practice partner at court before the disgrace), or remain faceless? | Narrative Director | Dialogue content phase | — |
| Exact tutorial board layout — positions of all pieces — needs to be designed and playtested to ensure the step sequence works cleanly. | Game Designer | Prototyping | — |
