# Dialogue System

> **Status**: In Design
> **Author**: user + game-designer
> **Last Updated**: 2026-03-28
> **Implements Pillar**: Narrative — giving voice to 13 opponents and the journey between them

## Overview

The Dialogue System delivers all character voice and narration in Fidchell as text — there is no voice acting or voice-over. It selects and displays short, context-aware dialogue (1–3 lines) before and after each match, drawn from a tagged dialogue database keyed to opponent ID, match history, feud state, reputation tier, and encounter context (first meeting, rematch, feud, nemesis, final boss). It also delivers narrator text — sparse, first-person prose that appears between scenes, describing the journey, the landscape, and the weight of the player's progress. The system includes its own UI: a dialogue overlay with character portrait, name, and text for opponent dialogue, and a distinct narrator presentation for journey prose. Dialogue is never interactive — there are no choices or branching paths. The player reads and taps to advance. The system's job is to make every match feel personal and every transition feel like a step on a road.

## Player Fantasy

The player should feel like each opponent is a real person who remembers them. Séanán's warmth, Brigid's silence, Tadhg's bluster — each voice should be immediately recognizable in a line or two. The dialogue should never feel generic or recycled. When an opponent references a previous loss, the player should think "they remember." When the narrator describes the road east, the player should feel the distance closing. The text is short by design — this is not a visual novel. It's the difference between a stranger and someone who knows your name. The absence of voice acting is intentional: the player reads at their own pace, and the words carry weight because they're spare.

## Detailed Design

### Core Rules

#### 1. Dialogue Types

| Type | When | Length | Presentation |
|------|------|--------|-------------|
| **Pre-match** | Before a match begins | 1–3 lines | Opponent portrait + name + text |
| **Post-match (win)** | After player wins | 1–2 lines | Opponent portrait + text |
| **Post-match (loss)** | After player loses | 1–2 lines | Opponent portrait + text |
| **Narrator** | Between chapters, between matches, after key moments | 1–4 lines | No portrait — distinct narrator style (italic, centred, or different background) |

#### 2. Context Tags

Every dialogue line is tagged with conditions. The system selects the most specific matching line. Tags:

| Tag | Values | Description |
|-----|--------|-------------|
| `opponent_id` | Character ID | Which opponent is speaking |
| `timing` | `pre_match`, `post_win`, `post_loss` | When the line appears |
| `encounter` | `first`, `second`, `third_plus` | How many times this opponent has been faced |
| `result_history` | `no_prior`, `lost_to_them`, `beat_them`, `mixed` | Player's win/loss record with this opponent |
| `feud_state` | `neutral`, `feud_pending`, `in_feud`, `feud_resolved`, `nemesis` | Current rivalry state (provisional — Feud System not yet designed) |
| `reputation_tier` | `unknown`, `emerging`, `respected`, `feared`, `legendary` | Player's reputation bracket |
| `is_chapter_boss` | `true`, `false` | Whether this is the chapter boss encounter |
| `is_final_boss` | `true`, `false` | Whether this is the Murchadh rematch |
| `match_type` | `standard`, `feud_rematch`, `guaranteed_rematch`, `scripted` | The nature of this encounter |

#### 3. Line Selection — Specificity Priority

When multiple lines match the current context, the system picks the most specific one:

```
1. Exact match on all tags (most specific — handcrafted for this exact moment)
2. Match on opponent_id + timing + feud_state + encounter
3. Match on opponent_id + timing + encounter
4. Match on opponent_id + timing (generic line for this character)
5. Fallback: generic line for timing only (no character — last resort)
```

The system always selects the **most specific** match available. This means a character can have a handful of generic lines and a few highly specific ones for key moments — the specific ones override when conditions match.

#### 4. Dialogue Database Structure

Lines are stored in an external data file (JSON or Godot Resource). Each entry:

```
{
  "id": "seanán_pre_first",
  "opponent_id": "seanán",
  "timing": "pre_match",
  "encounter": "first",
  "result_history": "no_prior",
  "feud_state": "neutral",
  "reputation_tier": null,
  "text": "Ah, a new face. Sit down, sit down. The board's been waiting."
}
```

A `null` tag means "match any" — the line applies regardless of that tag's value.

#### 5. Narrator Lines

Narrator text uses the same database but with `opponent_id: "narrator"` and additional tags:

| Tag | Values | Description |
|-----|--------|-------------|
| `chapter` | 0–4 | Which chapter transition |
| `trigger` | `chapter_start`, `chapter_end`, `post_boss`, `post_loss_streak`, `approaching_finale` | What triggered the narration |
| `reputation_tier` | As above | Player's standing |

Narrator lines are first-person, present tense, sparse:
> *"The road narrows. The trees here are older than the game I carry. Somewhere ahead, they are already talking about me."*

#### 6. Eithne an Chiúin — The Exception

Eithne does not speak. Her `opponent_id` returns no dialogue lines. The dialogue overlay does not appear for her pre-match or post-match. Instead:

- Pre-match: narrator line ("She says nothing. She gestures at the board.")
- Post-match: narrator line only ("She nods — once — and looks away.")

This is handled by having zero lines tagged to `eithne` and narrator lines tagged with `opponent_context: "eithne"`.

#### 7. Text Display

- Text appears one line at a time
- Player taps anywhere to advance to the next line
- After the last line, one more tap dismisses the dialogue overlay
- No auto-advance — the player controls pacing
- Text appears instantly (no typewriter effect) — the game's tone is unhurried, not cinematic

#### 8. Retry Dialogue

When the player retries a match they've lost:

- Pre-match dialogue changes. The system looks for lines tagged with `result_history: "lost_to_them"` and `encounter: "second"` (or `third_plus`).
- If no specific retry line exists, the generic pre-match line for that encounter count is used.
- Post-match dialogue after a retry win should acknowledge the effort: tagged with `result_history: "lost_to_them"` + `timing: "post_win"`.

### States and Transitions

| State | Entry Condition | Behavior | Exit Condition |
|-------|----------------|----------|----------------|
| **Inactive** | No dialogue requested | System idle. No overlay displayed. | Campaign System requests dialogue |
| **Selecting** | Dialogue requested with context | Query database for matching lines using context tags. Build line sequence. | Lines selected |
| **Displaying** | Lines ready | Push dialogue overlay via Scene Management. Show first line. Wait for tap. | Player taps through all lines |
| **Complete** | Last line dismissed | Pop dialogue overlay. Notify Campaign System that dialogue is complete. | Return to Inactive |

For narrator text, the flow is identical but the overlay uses narrator presentation (no portrait).

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Campaign System** | Campaign triggers dialogue | Campaign calls `show_dialogue(opponent_id, timing, context)` before and after matches. Context includes encounter count, result history, feud state, reputation tier. Dialogue emits `dialogue_complete` when finished. |
| **Feud System** | Feud provides state | Feud state is part of the context passed by Campaign. Dialogue System reads it but does not modify it. (Provisional — Feud System GDD not yet written.) |
| **Reputation System** | Reputation provides tier | Reputation tier is part of the context. Dialogue System calls `get_reputation_tier()`. |
| **Scene Management** | Dialogue uses overlays | Calls `push_overlay("dialogue")` to display, `pop_overlay()` when complete. |
| **Tutorial System** | Tutorial may trigger dialogue | Tutorial may request narrator lines during the guided match (e.g., explaining a rule in narrator voice). |

## Formulas

No mathematical formulas. Line selection is tag-matching logic with specificity priority, not calculation.

**Estimated dialogue volume:**

| Category | Lines per Character | Characters | Total |
|----------|-------------------|------------|-------|
| Pre-match (first, second, third+) | ~6 | 12 (excluding Eithne) | ~72 |
| Post-win (first, retry, feud) | ~4 | 12 | ~48 |
| Post-loss (first, repeated) | ~3 | 12 | ~36 |
| Feud-specific | ~4 | 6 (feud-prone characters) | ~24 |
| Nemesis-specific | ~2 | 6 | ~12 |
| Narrator | ~3 per trigger | ~10 triggers | ~30 |
| **Total estimated** | | | **~220 lines** |

This is manageable for a focused game. Each line is 1–3 sentences.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|-------------------|-----------|
| No matching line found for context | Fall back to generic timing line. If no generic exists, skip dialogue entirely (log warning). | The game should never crash or stall on missing dialogue |
| Eithne pre/post match | No opponent dialogue overlay. Narrator line plays instead. | Character design — she doesn't speak |
| Player has lost to same opponent 10+ times | `encounter: "third_plus"` lines are used. If a character has specific high-retry lines, those fire. Otherwise generic third_plus. | Dialogue shouldn't feel broken on repeated retries |
| Feud state is "nemesis" but no nemesis-specific line exists | Fall back to "in_feud" lines, then generic | Specificity cascade handles missing content gracefully |
| Player taps rapidly through dialogue | Each tap advances one line. No input is lost, no lines are skipped. Last tap dismisses. | Player controls pacing — rapid tapping means they've read it or want to skip |
| Narrator line triggers but no matching narrator entry | Skip narration. Campaign flow continues. | Missing narration shouldn't block gameplay |
| Prologue Murchadh — post-loss dialogue | Scripted defeat uses specific lines tagged `is_final_boss: false`, `match_type: "scripted"`. These are unique to the Prologue. | The Prologue loss is a story beat, not a gameplay loss — dialogue must reflect that |
| Same opponent appears twice (Conchobar Ch2 → Ch3) | Second appearance uses `encounter: "second"` tag. Dialogue references the prior meeting. | The system treats repeat encounters as one relationship across appearances |
| Dialogue displayed while match result is also pending | Dialogue plays first (post-match), then match result overlay displays after dialogue completes | Campaign System sequences these — dialogue before result |

## Dependencies

| System | Direction | Nature | Interface |
|--------|-----------|--------|-----------|
| **Campaign System** | This depends on | Hard — Campaign provides all dialogue context (opponent, history, timing) | `show_dialogue(opponent_id, timing, context)` |
| **Feud System** | This depends on | Soft — Feud state is part of context (provisional — assumes state machine from concept doc) | Feud state tag in context |
| **Reputation System** | This depends on | Soft — Reputation tier influences dialogue selection | `get_reputation_tier()` |
| **Scene Management** | This uses | Hard — dialogue is an overlay scene | `push_overlay("dialogue")`, `pop_overlay()` |
| **Tutorial System** | Depends on this | Soft — tutorial may request narrator-style lines | Narrator display with tutorial context |

**This system depends on:** Campaign System (hard), Scene Management (hard), Reputation System (soft), Feud System (soft/provisional).

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|--------------------|--------------------|
| `max_lines_per_dialogue` | 3 | 1–5 | More text per encounter — richer but slower | Terser — faster but less characterful |
| `narrator_max_lines` | 4 | 1–6 | More journey prose | Less narration |
| `tap_to_advance_delay` | 0.2s | 0.1–0.5s | Prevents accidental double-tap advancing | More responsive but risk of skipping |
| `text_display_mode` | instant | instant / typewriter | Instant: player reads at own pace | Typewriter: more cinematic but slower |
| `dialogue_line_count` per character | ~6–10 pre, ~4 post | 3–15 | More variety — less repetition on retries | Fewer lines — more recycling |

## Acceptance Criteria

- [ ] Pre-match dialogue displays before every standard match with correct opponent portrait and name
- [ ] Post-match dialogue displays after every match with win/loss-appropriate text
- [ ] Line selection picks most specific matching line based on context tags
- [ ] Fallback cascade works: specific → general → generic → skip (never crashes)
- [ ] Encounter count tracks correctly (first, second, third+)
- [ ] Result history influences line selection (lines change after losing to an opponent)
- [ ] Feud state influences line selection (feud/nemesis lines override neutral)
- [ ] Reputation tier influences line selection where applicable
- [ ] Eithne has no spoken dialogue — narrator lines appear instead
- [ ] Narrator text appears between chapters and at key story moments
- [ ] Player advances text by tapping — no auto-advance
- [ ] Dialogue overlay pushes/pops correctly via Scene Management
- [ ] `dialogue_complete` signal fires after last line dismissed
- [ ] Prologue scripted loss has unique dialogue (not generic post-loss)
- [ ] All dialogue loaded from external data file — no hardcoded text
- [ ] Dialogue lines are localization-ready (string keys, not inline text)

## Open Questions

| Question | Owner | Target Resolution | Resolution |
|----------|-------|-------------------|-----------|
| Should narrator text use a different visual treatment (italic, different background, no portrait frame) or share the dialogue overlay? | Art Director | Visual design phase | — |
| Should dialogue support simple text formatting (bold, italic) for emphasis, or plain text only? | UI Programmer | Implementation | — |
| How should the Prologue tutorial narrator lines work — integrated with the Tutorial System or standalone? | Game Designer | Tutorial System GDD | — |
| Should there be a dialogue log the player can review (list of past dialogue from the current session)? | UX Designer | Playtesting | — |
| When is the actual dialogue content written? Recommend after all system GDDs are done, using the `/team-narrative` workflow. | Narrative Director | Content phase | — |
