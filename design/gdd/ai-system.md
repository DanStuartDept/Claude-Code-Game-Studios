# AI System

> **Status**: Designed
> **Author**: user + game-designer
> **Last Updated**: 2026-03-28
> **Implements Pillar**: Core gameplay — opponents that feel like people, not algorithms

## Overview

The AI System provides opponents for Fidchell matches. It consumes board state and legal moves from the Board Rules Engine and returns a chosen move each turn. The system has two layers: a **core evaluator** that scores board positions and selects strong moves, and a **personality layer** that modifies which moves are preferred based on each opponent's play style (defensive, aggressive, tactical, erratic). Difficulty is controlled by limiting how deeply the evaluator searches and how often the personality layer overrides optimal play. The system must feel like 13 distinct people playing, not one algorithm at different speeds — Séanán should feel loose and instinctive, Brigid should feel patient and suffocating, and Murchadh should feel like he already knows what you're going to do.

## Player Fantasy

The player should feel like they are sitting across from a real person. Each opponent should have a recognizable style the player can learn to read and exploit — Brigid always seems to wait, Tadhg always pushes forward, Fiachra does something unexpected. Lower-difficulty opponents should feel human in their mistakes — not random, but flawed in characteristic ways (impatient, overconfident, blind to a particular tactic). Higher-difficulty opponents should feel intimidating — not because they're fast, but because they don't make mistakes and seem to anticipate the player's plans. Murchadh at difficulty 7 should feel like playing against someone who is genuinely better than you. Losing to him should feel earned, not cheap. Beating him should feel like the culmination of everything you've learned.

## Detailed Design

### Core Rules

#### 1. Architecture — Two-Layer AI

The AI System has two layers that execute in sequence each turn:

1. **Core Evaluator**: Searches the game tree using minimax with alpha-beta pruning, scoring board positions using a weighted heuristic function. Returns a ranked list of candidate moves.
2. **Personality Layer**: Reweights and filters the candidate moves based on the opponent's play style profile. Selects the final move.

```
AI Turn:
  1. Get legal_moves from Board Rules Engine
  2. Core Evaluator scores each move via minimax search
  3. Rank moves by score → candidate list
  4. Personality Layer adjusts rankings based on opponent profile
  5. Difficulty Layer applies mistake chance (may downgrade selection)
  6. Submit final move to Board Rules Engine
```

#### 2. Core Evaluator — Minimax with Alpha-Beta Pruning

The evaluator searches the game tree to a configurable depth, scoring leaf positions using a heuristic evaluation function.

**Search depth by difficulty:**

| Difficulty | Search Depth | Used By |
|------------|-------------|---------|
| 1 | 1 | Séanán (first opponent) |
| 2 | 1 | Brigid, Tadhg |
| 3 | 2 | Fiachra, Diarmait |
| 4 | 2 | Orlaith, Ruairí |
| 5 | 3 | Conchobar, Eithne, Caoimhe |
| 6 | 4 | Niall, Saoirse |
| 7 | 5 | Murchadh |

**Move ordering optimization**: To improve alpha-beta pruning efficiency, evaluate captures and King-adjacent moves first. This allows more branches to be pruned early.

#### 3. Position Evaluation Function

The heuristic scores a board position from the perspective of the AI's side. The score is a weighted sum of factors:

```
score = (w_material * material_score)
      + (w_king_freedom * king_freedom_score)
      + (w_king_proximity * king_proximity_score)
      + (w_board_control * board_control_score)
      + (w_threat * threat_score)
```

**Evaluation factors:**

| Factor | What It Measures | Attacker Perspective | Defender Perspective |
|--------|-----------------|---------------------|---------------------|
| `material_score` | Piece count advantage | +1 per defender captured, −1 per attacker lost | +1 per attacker captured, −1 per defender lost |
| `king_freedom_score` | King's available moves (legal move count) | Lower is better (King trapped) | Higher is better (King mobile) |
| `king_proximity_score` | King's distance to nearest corner | Further is better | Closer is better |
| `board_control_score` | Pieces occupying central or strategically valuable positions | Control around King matters | Control of escape routes matters |
| `threat_score` | Immediate tactical threats | Pieces adjacent to King, capture setups | Pieces protecting escape paths |

**Terminal position scores:**
- King reaches corner (Defender win): +10000 (Defender) / −10000 (Attacker)
- King captured (Attacker win): +10000 (Attacker) / −10000 (Defender)
- No legal moves: +10000 for the winning side

#### 4. Personality Layer — Weighted Scoring Profiles

Each opponent has a personality profile that adjusts the evaluation weights. This changes what the AI considers "best" without changing the search algorithm.

**Personality types and their weight adjustments:**

| Personality | material | king_freedom | king_proximity | board_control | threat | Behaviour |
|-------------|----------|-------------|---------------|--------------|--------|-----------|
| **Balanced** | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | No adjustment — plays "correctly" |
| **Defensive** | 0.8 | 1.5 | 0.7 | 1.2 | 0.6 | Prioritises King safety and board control over aggression |
| **Aggressive** | 1.3 | 0.7 | 1.4 | 0.8 | 1.5 | Chases captures and pushes toward King at the expense of position |
| **Tactical** | 1.0 | 1.0 | 0.8 | 1.3 | 1.4 | Values setups and positional advantage, creates multi-move traps |
| **Erratic** | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | Uses Balanced weights but applies random move disruption (see below) |

**Erratic disruption**: After scoring and ranking all moves, an erratic personality has a `disruption_chance` (e.g., 30%) of swapping the top-ranked move with a random move from the top 50% of candidates. This produces surprising but not suicidal play.

#### 5. Difficulty — Mistake Chance

In addition to search depth, lower-difficulty opponents have a chance to make suboptimal moves. This simulates human imperfection.

| Difficulty | Mistake Chance | Mistake Behaviour |
|------------|---------------|-------------------|
| 1 | 35% | Pick randomly from top 60% of moves |
| 2 | 25% | Pick randomly from top 50% of moves |
| 3 | 18% | Pick randomly from top 40% of moves |
| 4 | 12% | Pick 2nd or 3rd best move |
| 5 | 6% | Pick 2nd best move |
| 6 | 2% | Pick 2nd best move |
| 7 | 0% | Always plays the top-ranked move |

Mistake chance is rolled once per turn. If triggered, the AI downgrades its move selection. If not triggered, it plays the best move according to its personality weights.

#### 6. Opponent Profiles

Each of the 13 characters maps to a combination of difficulty, personality, and search depth:

| Character | Difficulty | Personality | Notes |
|-----------|-----------|-------------|-------|
| Séanán na Farraige | 1 | Erratic | Plays by feel, flashes of accidental brilliance |
| Brigid na Scailpe | 2 | Defensive | Patient, waits for overextension |
| Tadhg an Ósta | 2 | Aggressive | Pushes forward, boastful |
| Fiachra an Fhánaí | 3 | Tactical | Unpredictable — tactical with occasional creative moves |
| Orlaith na gCros | 4 | Defensive | Immovable, maximises King escape routes |
| Diarmait Óg | 3 | Aggressive | Fast, reckless, sometimes brilliant by accident |
| Conchobar Críonna | 5 | Tactical | Teacher-like precision, contemptuous |
| Eithne an Chiúin | 5 | Balanced | Mechanical efficiency, no wasted moves |
| Ruairí an Bhaird | 4 | Erratic | Makes the dramatic move, not the correct one |
| Caoimhe an Léinn | 5 | Tactical | Disrupts player plans rather than executing her own |
| Niall na Naoi gCailleadh | 6 | Balanced | The best you'll face before the final chapter |
| Saoirse na Cúirte | 6 | Tactical | Exposes weaknesses, tests readiness |
| Murchadh mac Fáelán | 7 | Balanced | Optimal play. No mistakes. No personality quirks. Just wins. |

**Feud difficulty scaling**: When an opponent returns in a feud or nemesis state, their difficulty increases by 1 (capped at 7). This reduces mistake chance and may increase search depth. The Campaign System provides the current difficulty override.

#### 7. Think Time

The AI must not respond instantly — it should feel like the opponent is considering their move. A deliberate delay is added before submitting the move.

| Difficulty | Think Time |
|------------|-----------|
| 1–2 | 0.5–1.5s (random) |
| 3–4 | 1.0–2.0s (random) |
| 5–6 | 1.5–3.0s (random) |
| 7 | 2.0–4.0s (random) |

Think time is cosmetic — the AI computes its move immediately, then waits before submitting. If actual computation exceeds the think time (unlikely on a 7×7 board), the move is submitted as soon as computation finishes.

### States and Transitions

| State | Entry Condition | Behavior | Exit Condition |
|-------|----------------|----------|----------------|
| **Idle** | No match active, or it's the player's turn | Waiting. No computation. | Board Rules Engine emits `turn_changed` to AI's side |
| **Evaluating** | AI's turn begins | Run minimax search, apply personality weights, roll mistake chance, select final move | Move selected |
| **Waiting** | Move selected | Hold for think time delay | Think time elapsed |
| **Submitting** | Think time complete | Call `submit_move(from, to)` on Board Rules Engine | Move accepted |

**Cycle per turn:** Idle → Evaluating → Waiting → Submitting → Idle

The AI listens for `turn_changed` from the Board Rules Engine. When the active side matches the AI's assigned side, it transitions from Idle to Evaluating. After submitting, it returns to Idle until its next turn.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Board Rules Engine** | AI consumes | Calls `get_board_state()` to read current positions. Calls `get_legal_moves(side)` to get available moves. Calls `submit_move(from, to)` to play. Listens to `turn_changed` to know when it's the AI's turn. |
| **Campaign System** | Campaign configures AI | Campaign provides the opponent profile for each match: character ID, difficulty level (may be overridden by feud scaling), assigned side (Attacker or Defender). AI does not know about campaign structure — it just receives configuration. |
| **Board UI** | No direct interaction | Board UI renders the AI's moves via Board Rules Engine signals (`piece_moved`, `piece_captured`). The AI never communicates with the UI directly. |
| **Tutorial System** | Tutorial may override AI | During tutorial matches, the Tutorial System may provide a scripted move sequence instead of letting the AI evaluate freely. The AI checks for a tutorial override before evaluating. |

**The AI System never emits signals to other systems.** It is a consumer of board state and a submitter of moves. All downstream effects (rendering, sound, campaign updates) flow through the Board Rules Engine's signals.

## Formulas

### Position Evaluation

```
score = (w_material * material_score)
      + (w_king_freedom * king_freedom_score)
      + (w_king_proximity * king_proximity_score)
      + (w_board_control * board_control_score)
      + (w_threat * threat_score)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `w_material` | float | 0.5–1.5 | Personality profile | Weight for piece advantage |
| `w_king_freedom` | float | 0.5–1.5 | Personality profile | Weight for King mobility |
| `w_king_proximity` | float | 0.5–1.5 | Personality profile | Weight for King distance to corners |
| `w_board_control` | float | 0.5–1.5 | Personality profile | Weight for positional strength |
| `w_threat` | float | 0.5–1.5 | Personality profile | Weight for immediate tactical threats |

### Material Score

```
material_score = (friendly_piece_count - starting_friendly_count_penalty)
               - (enemy_piece_count - starting_enemy_count_penalty)
```

Normalized so that full starting pieces = 0, each capture shifts score by ±1.

**Expected range:** −16 to +9 (Attacker perspective, all defenders captured vs all attackers captured)

### King Freedom Score

```
king_freedom_score = king_legal_move_count / max_possible_moves
```

**Expected range:** 0.0 (King completely trapped) to 1.0 (King has maximum mobility)

Measured from the side evaluating. Attackers want this low; Defenders want this high. The sign is flipped internally based on which side the AI plays.

### King Proximity Score

```
king_proximity_score = 1.0 - (min_corner_distance / max_possible_distance)
```

Where `min_corner_distance` = Manhattan distance from King to nearest corner tile.
Where `max_possible_distance` = 6 (from centre (3,3) to any corner on a 7×7 board).

**Expected range:** 0.0 (King at centre, furthest from corners) to 1.0 (King adjacent to corner)

### Board Control Score

```
board_control_score = friendly_pieces_in_zone / total_zone_cells
```

**Zone definition:**
- For Attackers: the 8 cells surrounding the King (3×3 minus King)
- For Defenders: the 4 corner-adjacent corridors (cells on row 0, row 6, col 0, col 6 excluding corners themselves)

**Expected range:** 0.0 to 1.0

### Threat Score

```
threat_score = capture_threat_count * 0.5 + king_adjacent_attacker_count * 0.3
```

Where `capture_threat_count` = number of enemy pieces that could be captured next move.
Where `king_adjacent_attacker_count` = attackers orthogonally adjacent to King (0–4).

**Expected range:** 0.0 to ~4.0

### Mistake Roll

```
makes_mistake = random() < mistake_chance[difficulty]
if makes_mistake:
    selected_move = random_choice(candidates[0 : ceil(len(candidates) * pool_fraction)])
else:
    selected_move = candidates[0]  # best move
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `mistake_chance` | float | 0.0–0.35 | Difficulty table | Probability of suboptimal move |
| `pool_fraction` | float | 0.4–0.6 | Difficulty table | How deep into the ranked list mistakes can reach |

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|-------------------|-----------|
| AI has only one legal move | Skip evaluation, submit immediately (still apply think time) | No decision to make — save CPU |
| All candidate moves are equally scored | Pick randomly among tied moves | Prevents deterministic, predictable play |
| Mistake roll selects a move that leads to immediate King capture (losing) | Exclude terminal-loss moves from the mistake pool | Mistakes should feel human, not suicidal |
| Feud scaling pushes difficulty above 7 | Cap at 7 | Difficulty 7 is already maximum search depth and zero mistakes |
| AI plays as Defender (player is Attacker) | Evaluation function signs flip — AI wants King freedom high and King proximity high | The AI must support playing either side |
| Search depth 5 takes longer than expected on low-end mobile | Implement iterative deepening — return best move found so far if time budget (200ms) is exceeded | Guarantees responsiveness on all devices |
| Board has very few pieces remaining (endgame) | Search is naturally faster (fewer branches) — no special handling needed | Alpha-beta on a sparse 7×7 board is trivially fast |
| Tutorial override provides a scripted move | Skip evaluation entirely, submit the scripted move with think time | Tutorial owns the AI during guided sequences |
| Erratic disruption selects same move as top-ranked | No visible effect — this is fine, the roll just happened to agree | Don't force a different move; that would bias against good plays |
| AI needs to evaluate board but match is in Scripted mode | AI is never invoked for Scripted matches — Campaign System handles this | Board Rules Engine skips the turn cycle in Scripted mode |

## Dependencies

| System | Direction | Nature | Interface |
|--------|-----------|--------|-----------|
| **Board Rules Engine** | This depends on | Hard — AI cannot function without board state and legal moves | `get_board_state()`, `get_legal_moves(side)`, `submit_move(from, to)`, `turn_changed` signal |
| **Campaign System** | Depends on this | Hard — campaign needs AI to run opponent matches | Campaign provides: character ID, difficulty, side assignment. AI returns: moves (via Board Rules Engine). |
| **Tutorial System** | May override this | Soft — tutorial can provide scripted moves instead of AI evaluation | Tutorial provides: scripted move or null. AI checks before evaluating. |

**This system depends on:** Board Rules Engine (hard dependency — defined in its GDD).

**Bidirectional note:** When the Campaign System and Tutorial System GDDs are written, each must list AI System as a dependency and reference the configuration interface (character ID, difficulty, side assignment) and override interface (scripted moves).

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|--------------------|--------------------|
| `search_depth[difficulty]` | 1,1,2,2,3,4,5 | 1–6 | Stronger play, longer computation | Weaker play, faster computation |
| `mistake_chance[difficulty]` | 0.35,0.25,0.18,0.12,0.06,0.02,0.0 | 0.0–0.5 | More frequent blunders, feels easier | Fewer mistakes, feels harder |
| `mistake_pool_fraction[difficulty]` | 0.6,0.5,0.4,0.3,0.3,0.3,0.0 | 0.2–0.8 | Mistakes are wilder (deeper into ranked list) | Mistakes are subtle (close to optimal) |
| `erratic_disruption_chance` | 0.30 | 0.1–0.5 | More unpredictable play for erratic characters | More consistent play |
| `w_material` | Per personality table | 0.5–1.5 | AI values captures more | AI ignores piece advantage |
| `w_king_freedom` | Per personality table | 0.5–1.5 | AI prioritises King mobility | AI ignores King's movement options |
| `w_king_proximity` | Per personality table | 0.5–1.5 | AI pushes toward/away from corners harder | AI is indifferent to King's position |
| `w_board_control` | Per personality table | 0.5–1.5 | AI plays positionally | AI ignores board control |
| `w_threat` | Per personality table | 0.5–1.5 | AI plays tactically (threats and captures) | AI plays passively |
| `think_time_min[difficulty]` | 0.5,0.5,1.0,1.0,1.5,1.5,2.0 | 0.3–3.0s | Feels more deliberate | Feels snappier |
| `think_time_max[difficulty]` | 1.5,1.5,2.0,2.0,3.0,3.0,4.0 | 1.0–5.0s | Long pauses may frustrate | Less "thinking" feel |
| `computation_time_budget` | 200ms | 100–500ms | Allows deeper search on slow devices | Snappier but may truncate search |
| `feud_difficulty_bonus` | +1 | 0–2 | Feud rematches are much harder | Feud rematches barely change |

**Critical interactions:**
- `search_depth` and `computation_time_budget` interact — deeper search on slow hardware may hit the budget. Iterative deepening handles this gracefully.
- `mistake_chance` and personality weights interact — a defensive AI that also makes frequent mistakes feels confused rather than defensive. Keep mistake_chance low for strong personality differentiation.

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| AI is "thinking" | Subtle animation on opponent portrait or a thinking indicator (e.g., hand hovering over board) | None — silence during thinking adds tension | Medium |
| AI submits move | No special feedback — the Board Rules Engine's `piece_moved` signal drives the piece animation | None — handled by Board UI / Audio System | N/A |
| AI makes a mistake (low difficulty) | No visual tell — the player should not know the AI blundered | None | N/A |
| AI captures a player piece | No AI-specific feedback — same capture animation as any move | None — handled by Audio System | N/A |

**Note:** The AI System is invisible to the player. All visual/audio feedback for moves, captures, and results is handled by Board UI and Audio System via Board Rules Engine signals. The only AI-specific visual element is the thinking indicator, which is owned by Board UI.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|-----------------|-----------|
| Opponent thinking indicator | Near opponent portrait or board edge | On AI turn start/end | During AI's turn only |
| Opponent name and portrait | Match screen header | Per match | Always during match |
| Opponent difficulty | Not displayed — player should read difficulty through play, not a number | Never | Never |

**Note:** Opponent personality and difficulty are invisible to the player. The player experiences them through how the AI plays, not through UI labels. Opponent identity (name, portrait) is provided by the Campaign System and rendered by Board UI.

## Acceptance Criteria

- [ ] AI selects and submits a valid legal move every turn
- [ ] Difficulty 1 opponent is beatable by a first-time player within 2–3 attempts
- [ ] Difficulty 7 opponent wins the majority of matches against an intermediate player
- [ ] Each personality type produces visibly different play patterns (defensive holds position, aggressive chases, tactical sets traps, erratic surprises)
- [ ] Two matches against the same opponent at the same difficulty do not play out identically
- [ ] Mistake chance produces human-feeling errors, not suicidal moves (no terminal-loss moves in mistake pool)
- [ ] Feud difficulty scaling increases opponent strength noticeably (+1 difficulty)
- [ ] Think time delay feels natural — not instant, not frustrating
- [ ] AI evaluation completes within 200ms computation budget on target mobile hardware
- [ ] Iterative deepening returns a valid move even if time budget is exceeded at target depth
- [ ] AI correctly plays as either Attacker or Defender based on side assignment
- [ ] Tutorial scripted move override works — AI submits provided move without evaluation
- [ ] All 13 opponent profiles are configured and produce distinct play experiences
- [ ] No hardcoded values — all difficulty tables, personality weights, and think times defined in external data
- [ ] AI does not visibly "cheat" (no access to information a human opponent wouldn't have)

## Open Questions

| Question | Owner | Target Resolution | Resolution |
|----------|-------|-------------------|-----------|
| Should the AI pre-compute during the player's turn (background thinking) to reduce apparent think time? | Gameplay Programmer | Implementation phase | — |
| Do personality weights need per-character fine-tuning beyond the 5 personality types, or are the types sufficient? | Game Designer | Playtesting | — |
| Should there be a "hint" system where the AI evaluates the player's position and suggests a move? This could help accessibility but may undermine the challenge. | Game Designer | Tutorial System / Accessibility GDD | — |
| Is Caoimhe's "disruptive" style (disrupts player plans) achievable with weighted scoring alone, or does she need a custom evaluation that specifically counters the player's likely strategy? | AI Programmer | Prototyping | — |
