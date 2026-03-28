# Reputation System

> **Status**: Designed
> **Author**: user + game-designer
> **Last Updated**: 2026-03-28
> **Implements Pillar**: Progression — the measure of the player's journey back to Tara

## Overview

Reputation is a single numeric score that tracks the player's standing across the campaign. It increases when the player wins matches, with bonuses for winning quickly, winning feuds, and winning rematches. It never decreases. Reputation gates chapter access — each chapter requires a minimum score to enter. It also influences how opponents speak to the player through the Dialogue System. The system is deliberately simple: one number, always going up, visible on the campaign map. It is the player's proof that they are earning their way back to Tara.

## Player Fantasy

The player should feel their reputation growing like a tide — slow at first, then undeniable. Early in the campaign, the number is low and opponents don't know who you are. By the midgame, the number has weight — rivals have heard of you, dialogue shifts, doors open. Reaching the thresholds for new chapters should feel like arriving somewhere you've earned the right to be. The reputation score is not a gamey XP bar — it's the story of your journey told as a single number.

## Detailed Design

### Core Rules

#### 1. Score Properties

- **Type:** Integer, starting at 0
- **Direction:** Only increases. Never decreases. Losses award 0 reputation.
- **Cap:** None — reputation can exceed 80 (the final boss threshold). There is no maximum.
- **Persistence:** Saved as part of campaign state via Save System.

#### 2. Reputation Sources

| Source | Base Amount | Condition |
|--------|-----------|-----------|
| **Match win** | 5 | Win any campaign match |
| **Speed bonus** | +2 | Win in ≤ 20 moves |
| **Decisive bonus** | +1 | Win with ≥ 5 defender pieces remaining (including King) |
| **Feud win** | +3 | Win a feud rematch |
| **Nemesis win** | +5 | Defeat a Nemesis-state opponent |
| **Chapter boss win** | +3 | Defeat a chapter boss |
| **Rematch win** | +1 | Win against an opponent you've previously lost to |

Bonuses stack. A fast feud win against a chapter boss could earn: 5 (base) + 2 (speed) + 1 (decisive) + 3 (feud) + 3 (boss) = 14 reputation from a single match.

#### 3. Non-Sources

| Action | Reputation Earned |
|--------|------------------|
| Losing a match | 0 |
| Replaying a completed match | 0 |
| Quick Play matches | 0 |
| Prologue matches (tutorial + scripted loss) | 0 |

#### 4. Chapter Thresholds

| Threshold | Unlocks |
|-----------|---------|
| 0 | Chapter 1 (automatic after Prologue) |
| 15 | Chapter 2 |
| 35 | Chapter 3 |
| 60 | Chapter 4 |
| 80 | Final boss match (Murchadh) |

#### 5. Dialogue Influence

Reputation is passed to the Dialogue System as context. Dialogue does not change at exact thresholds — instead, opponents check broad reputation tiers:

| Tier | Range | Dialogue Tone |
|------|-------|---------------|
| Unknown | 0–10 | Opponents don't know who you are |
| Emerging | 11–30 | Word is spreading. Some have heard of the disgrace. |
| Respected | 31–55 | You are taken seriously. Opponents prepare. |
| Feared | 56–79 | Opponents know your record. Dialogue shifts to respect or wariness. |
| Legendary | 80+ | You are the player who came back. Even Murchadh acknowledges it. |

### States and Transitions

No state machine — reputation is a single accumulating value. It has no states or transitions. It changes only when the Campaign System reports a match result.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Campaign System** | Campaign feeds results | Campaign calls `award_reputation(match_result)` after each win. Reputation returns the amount earned. Campaign checks `get_reputation()` against chapter thresholds. |
| **Feud System** | Feud provides bonus flags | Feud System tells Reputation whether the match was a feud win or nemesis win — Reputation applies the appropriate bonus. |
| **Dialogue System** | Dialogue reads reputation | Dialogue System calls `get_reputation_tier()` to select tone-appropriate text. |
| **Save System** | Save persists reputation | Reputation value is part of the campaign state serialized by Save System. |
| **Campaign UI** | UI displays reputation | Campaign UI reads `get_reputation()` and `get_next_threshold()` for display. |

## Formulas

### Reputation Award Calculation

```
reputation_earned = base_win
                  + (speed_bonus IF move_count <= speed_threshold)
                  + (decisive_bonus IF defenders_remaining >= decisive_threshold)
                  + (feud_bonus IF is_feud_win)
                  + (nemesis_bonus IF is_nemesis_win)
                  + (boss_bonus IF is_chapter_boss)
                  + (rematch_bonus IF has_previous_loss_to_opponent)
```

| Variable | Type | Value | Source | Description |
|----------|------|-------|--------|-------------|
| `base_win` | int | 5 | Config | Base reputation for any campaign win |
| `speed_bonus` | int | 2 | Config | Bonus for winning in ≤ speed_threshold moves |
| `speed_threshold` | int | 20 | Config | Maximum moves to qualify for speed bonus |
| `decisive_bonus` | int | 1 | Config | Bonus for winning with many pieces remaining |
| `decisive_threshold` | int | 5 | Config | Minimum defender pieces remaining (including King) |
| `feud_bonus` | int | 3 | Config | Bonus for winning a feud rematch |
| `nemesis_bonus` | int | 5 | Config | Bonus for defeating a Nemesis |
| `boss_bonus` | int | 3 | Config | Bonus for defeating a chapter boss |
| `rematch_bonus` | int | 1 | Config | Bonus for beating an opponent who previously beat you |

**Expected reputation per chapter (winning all matches, no bonuses):**
- Chapter 1: 4 wins × 5 = 20 (threshold for Ch2: 15 ✓)
- Chapter 2: 4 wins × 5 = 20 (cumulative: 40, threshold for Ch3: 35 ✓)
- Chapter 3: 5 wins × 5 = 25 (cumulative: 65, threshold for Ch4: 60 ✓)
- Chapter 4: 3 wins × 5 = 15 (cumulative: 80, threshold for final boss: 80 ✓)

This means a player who wins every match without bonuses barely reaches each threshold — bonuses provide comfortable margin, and losses may require feud wins to compensate.

### Reputation Tier Lookup

```
tier = "unknown"    IF reputation <= 10
tier = "emerging"   IF reputation <= 30
tier = "respected"  IF reputation <= 55
tier = "feared"     IF reputation <= 79
tier = "legendary"  IF reputation >= 80
```

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|-------------------|-----------|
| Player wins every match with speed + decisive bonuses | Reputation accumulates well above thresholds. No cap — high reputation is a badge of skill. | Rewarding skilled play, no punishment for being good |
| Player wins slowly with many losses along the way | Reputation accumulates slowly. May need feud wins or rematches to reach thresholds. | The system naturally paces struggling players without hard blocks |
| Player earns speed bonus AND feud bonus AND boss bonus on same match | All bonuses stack. Maximum single-match earn: 5+2+1+3+5+3+1 = 20 (nemesis chapter boss feud rematch with speed and decisive) | Dramatic moments should feel dramatically rewarding |
| Player replays completed matches for reputation | No reputation earned on replay. Clearly communicated in post-match result. | Prevents trivial grinding — reputation must come from new victories |
| Reputation exceeds 80 | No effect beyond 80 — all thresholds are already met. The number continues to accumulate as a personal score. | A high final reputation could be displayed in credits or used as a badge |
| Player reaches boss with exactly the threshold | Boss unlocks. No margin required — exact match is sufficient. | Clean gating — ≥ threshold, not > threshold |
| Feud System reports both feud_win and nemesis_win | Both bonuses apply. Nemesis is a subset of feud — the player earned both. | A nemesis win is the hardest possible feud outcome and deserves maximum reward |

## Dependencies

| System | Direction | Nature | Interface |
|--------|-----------|--------|-----------|
| **Campaign System** | This depends on | Hard — Campaign provides match results that trigger reputation awards | `award_reputation(match_result)` |
| **Feud System** | Depends on this / provides flags | Soft bidirectional — Feud provides bonus flags, Feud also checks reputation for some escalation triggers | Feud bonus flags in, reputation value out |
| **Dialogue System** | Depends on this | Soft — reads reputation tier for tone selection | `get_reputation_tier()` |
| **Save System** | Depends on this | Hard — persists reputation value | Reputation value as part of campaign state |
| **Campaign UI** | Depends on this | Hard — displays reputation and progress to next threshold | `get_reputation()`, `get_next_threshold()` |

**This system depends on:** Campaign System (hard).

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|--------------------|--------------------|
| `base_win` | 5 | 3–8 | Faster progression, more margin | Slower progression, tighter thresholds |
| `speed_bonus` | 2 | 0–5 | Rewards fast play more | Less incentive to play quickly |
| `speed_threshold` | 20 moves | 15–30 | Harder to earn speed bonus | Easier to earn speed bonus |
| `decisive_bonus` | 1 | 0–3 | Rewards clean wins more | Less incentive for piece preservation |
| `decisive_threshold` | 5 pieces | 3–7 | Harder to earn decisive bonus | Easier to earn decisive bonus |
| `feud_bonus` | 3 | 1–5 | Feuds feel more rewarding | Feuds feel less impactful |
| `nemesis_bonus` | 5 | 3–8 | Nemesis defeats are major milestones | Nemesis defeats feel routine |
| `boss_bonus` | 3 | 1–5 | Boss victories feel important | Boss victories feel ordinary |
| `chapter_thresholds` | [0,0,15,35,60] | Various | Higher = harder progression | Lower = easier progression |
| `final_boss_threshold` | 80 | 60–100 | More demanding — player must earn bonuses | More accessible final confrontation |
| `dialogue_tier_ranges` | [10,30,55,79] | Various | Tiers shift — dialogue tone changes earlier/later | Dialogue tone stays the same longer |

**Critical interaction:** `base_win` × average matches per chapter must roughly equal the next chapter's threshold. The current values (5 × 4 = 20 vs. threshold 15) provide ~33% margin. Reducing `base_win` below 4 risks making progression feel punishing.

## Acceptance Criteria

- [ ] Reputation starts at 0 for new campaign
- [ ] Winning a match awards base reputation (5)
- [ ] Speed bonus awards correctly when move count ≤ 20
- [ ] Decisive bonus awards correctly when ≥ 5 defenders remain
- [ ] Feud, nemesis, boss, and rematch bonuses each apply correctly
- [ ] All bonuses stack on a single match
- [ ] Losing a match awards 0 reputation
- [ ] Replaying a completed match awards 0 reputation
- [ ] Quick Play awards 0 reputation
- [ ] Reputation never decreases
- [ ] Chapter thresholds gate correctly (≥ threshold unlocks)
- [ ] Reputation tier lookup returns correct tier for all ranges
- [ ] Post-match display shows reputation earned with bonus breakdown
- [ ] Campaign UI shows current reputation and progress to next threshold
- [ ] All values loaded from external config — no hardcoded amounts
- [ ] Expected progression math holds: winning all matches without bonuses reaches each threshold

## Open Questions

| Question | Owner | Target Resolution | Resolution |
|----------|-------|-------------------|-----------|
| Should reputation be displayed as a number, a progress bar, or a narrative metaphor (e.g., "word of you has spread to Munster")? | UX Designer | Campaign UI GDD | — |
| Should there be a "total reputation" leaderboard or achievement for reaching high scores? | Game Designer | Post-launch / Full Vision | — |
| Is the speed threshold (20 moves) appropriate? Needs playtesting to determine average match length. | Game Designer | Prototyping | — |
