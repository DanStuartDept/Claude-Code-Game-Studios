# Campaign System

> **Status**: Designed
> **Author**: user + game-designer
> **Last Updated**: 2026-03-28
> **Implements Pillar**: Core experience — the journey from disgrace to return

## Overview

The Campaign System is the narrative spine of Fidchell. It manages the 5-chapter journey from disgrace at Tara to the final rematch against Murchadh — sequencing matches, tracking which opponents appear, assigning sides (Attacker/Defender), and gating chapter access through the Reputation System. It owns the 13 opponent profiles (name, difficulty, personality, feud tendency, chapter placement) and the match schedule, including dynamically injected feud rematches from the Feud System. It drives scene flow by calling Scene Management to transition between campaign map, dialogue, and match screens. The Campaign System also handles the Prologue's scripted loss and Quick Play mode (standalone matches outside the campaign). It is the connective tissue between every other system — the Board Rules Engine plays the game, the AI plays the opponent, but the Campaign System decides *which* opponent, *where*, and *why*.

## Player Fantasy

The player should feel like they are on a road — not a menu selecting levels, but a journey moving east through Ireland. Each match should feel like an encounter with a real person in a real place, not a difficulty tier. The campaign should build: early matches feel like scraping by, middle matches feel like proving yourself, late matches feel like a reckoning. The player should feel the weight of their history — opponents who remember them, feuds that followed them, a final confrontation that has been building since the opening scene. Losing should not feel like failure but like a setback on a longer road. The campaign structure should be invisible — the player should feel like they're living a story, not progressing through a system.

## Detailed Design

### Core Rules

#### 1. Campaign Structure

The campaign is a linear 5-chapter journey. Each chapter has a location, a set of fixed matches, and optional feud matches injected by the Feud System.

| Chapter | Name | Location | Fixed Matches | Chapter Boss | Rep Required |
|---------|------|----------|--------------|--------------|-------------|
| 0 | Prologue: The Disgrace | Tara, The High Court | 2 (tutorial + scripted loss) | Murchadh mac Fáelán | 0 |
| 1 | The West | Connacht, the wild shore | 4 | Fiachra an Fhánaí | 0 |
| 2 | The Old Roads | Munster / Leinster border | 4 | Conchobar Críonna | 15 |
| 3 | The Midlands | Heart of Ireland | 5 | Niall na Naoi gCailleadh | 35 |
| 4 | The Return | Leinster, approaching Tara | 3 + final boss | Murchadh mac Fáelán | 60 (80 for final boss) |

Total fixed matches: ~18–20. Feud rematches may add 2–5 additional matches depending on player history.

#### 2. Side Assignment

The player always plays as **Defender** (Light side — 8 Defenders + the King). The AI always plays as Attacker (Dark side — 16 pieces).

This is a narrative choice: the King's escape from encirclement mirrors the player's journey from exile back to Tara. The closing attackers mirror the pressure of rivals and reputation. The asymmetry is always experienced from the same side, letting the player master the Defender's strategy across the full campaign.

#### 3. Match Schedule — Full Opponent List

| Order | Chapter | Opponent | Difficulty | Personality | Match Type |
|-------|---------|----------|-----------|-------------|------------|
| 1 | 0 | Tutorial opponent (narrator-guided) | — | — | Tutorial |
| 2 | 0 | Murchadh mac Fáelán | 7 | Balanced | Scripted loss (cutscene) |
| 3 | 1 | Séanán na Farraige | 1 | Erratic | Standard |
| 4 | 1 | Brigid na Scailpe | 2 | Defensive | Standard |
| 5 | 1 | Tadhg an Ósta | 2 | Aggressive | Standard |
| 6 | 1 | Fiachra an Fhánaí | 3 | Tactical | Standard (Chapter 1 boss) |
| 7 | 2 | Orlaith na gCros | 4 | Defensive | Standard |
| 8 | 2 | Diarmait Óg | 3 | Aggressive | Standard |
| 9 | 2 | Caoimhe an Léinn (1st) | 5 | Tactical | Standard |
| 10 | 2 | Conchobar Críonna | 5 | Tactical | Standard (Chapter 2 boss) |
| 11 | 3 | Eithne an Chiúin | 5 | Balanced | Standard |
| 12 | 3 | Ruairí an Bhaird | 4 | Erratic | Standard (or replaced by feud rematch) |
| 13 | 3 | Conchobar Críonna (rematch) | 6 | Tactical | Rematch (harder) |
| 14 | 3 | Feud slot | Varies | Varies | Injected by Feud System if active; otherwise Ruairí |
| 15 | 3 | Niall na Naoi gCailleadh | 6 | Balanced | Standard (Chapter 3 boss) |
| 16 | 4 | Caoimhe an Léinn (2nd) | 6 | Tactical | Standard (scaled up) |
| 17 | 4 | Saoirse na Cúirte | 6 | Tactical | Standard (gatekeeper) |
| 18 | 4 | Murchadh mac Fáelán | 7 | Balanced | Final boss |

**Feud injection slots:** Chapters 2, 3, and 4 each have one flexible slot where the Feud System can insert a rematch. If no feud is active for that slot, a default opponent fills it (e.g., Ruairí in Chapter 3).

#### 4. Match Ordering Within a Chapter

Matches within a chapter are **linear** — the player plays them in order. This supports the narrative pacing (each chapter builds to its boss) and simplifies the campaign map. The player cannot skip ahead or choose out of order.

However, a completed match is always replayable for practice (no additional reputation earned from replays).

#### 5. Losing a Match

When the player loses a campaign match:

1. Post-match dialogue plays — the opponent reacts to their victory. Dialogue varies based on match history (first loss vs. repeated losses).
2. The opponent's feud tendency is checked — if high, a feud flag may be set (see Feud System).
3. The player remains at the same match position — they can retry immediately.
4. No reputation is lost. Reputation only stalls — it cannot decrease.
5. On retry, pre-match dialogue changes to acknowledge the rematch ("Back again?").
6. The AI re-rolls its mistake chances — the same opponent may play slightly differently on retry.

There is no limit on retries. The player is never locked out of progression — they can always try again.

#### 6. Winning a Match

When the player wins a campaign match:

1. Post-match dialogue plays — the opponent reacts to their defeat.
2. Reputation is awarded (base + bonuses — see Reputation System).
3. The opponent's feud tendency is checked for grudge triggers.
4. Match result is recorded in match history (win, move count, side).
5. The next match in the chapter unlocks.
6. If the match was a chapter boss and the player has enough reputation for the next chapter, the next chapter unlocks.

#### 7. Chapter Gating

A chapter is accessible when:
- The previous chapter's boss is defeated, AND
- The player's reputation meets the chapter's threshold

If the player defeats a chapter boss but lacks reputation for the next chapter, they must replay earlier matches or win feud rematches to earn more reputation. This should be rare — normal play should accumulate enough reputation naturally.

#### 8. The Prologue

Chapter 0 is unique:

| Match | Type | Behaviour |
|-------|------|-----------|
| Tutorial | Tutorial mode | Board Rules Engine + Tutorial System. Guided match teaching basic rules. AI plays scripted moves. |
| Murchadh | Scripted | Presented as a cutscene — the player watches or reads the defeat. No interactive gameplay. Board Rules Engine runs in Scripted mode. |

After the Prologue, the player is placed in Chapter 1 with 0 reputation. The Prologue is not replayable.

#### 9. Quick Play Mode

Accessed from the main menu, separate from the campaign:

- Player chooses an opponent from any character they've encountered in the campaign (unlocked progressively)
- Player can choose difficulty (the opponent's campaign difficulty ±1)
- No reputation earned, no feud consequences
- Match result is not recorded in campaign history
- Uses the same Board Rules Engine and AI System

Quick Play serves as practice and replayability after the campaign is complete.

#### 10. Opponent Profiles — Data Structure

Each opponent is defined as a data record:

```
opponent:
  id: "seanán"
  name: "Séanán na Farraige"
  title: "Séanán of the Shore"
  location: "Connacht coast"
  chapter: 1
  match_order: 1
  difficulty: 1
  personality: "erratic"
  feud_tendency: 0.1        # low — he doesn't hold grudges
  is_chapter_boss: false
  portrait: "res://assets/art/portraits/seanán.png"
  description: "A fisherman who plays by feel..."
```

All 13 profiles are stored in an external data file (JSON or Godot Resource). No opponent data is hardcoded.

### States and Transitions

| State | Entry Condition | Behavior | Exit Condition |
|-------|----------------|----------|----------------|
| **Title** | App launched, main menu displayed | Awaiting player choice: New Game, Continue, Quick Play | Player selects an option |
| **New Game** | Player starts new campaign | Reset all progress. Begin Prologue (Chapter 0). | Prologue loads |
| **Campaign Map** | Chapter active, between matches | Display current chapter, next opponent, reputation. Await player to start next match. | Player initiates match |
| **Pre-Match** | Match initiated | Load opponent profile. Push dialogue overlay for pre-match dialogue. | Dialogue complete |
| **Match Active** | Pre-match dialogue dismissed | Call `start_match()` on Board Rules Engine with opponent config (difficulty, personality, side assignment, match mode). Wait for `match_ended` signal. | `match_ended` received |
| **Post-Match** | Match ended | Process result: record history, award reputation, check feud triggers. Push dialogue overlay for post-match dialogue. Push match result overlay. | Player dismisses result |
| **Chapter Complete** | Chapter boss defeated + reputation threshold met | Transition narration. Unlock next chapter. Return to Campaign Map. | Next chapter loads |
| **Campaign Complete** | Murchadh defeated in Chapter 4 | Ending sequence — final narration, credits. | Player returns to main menu |
| **Quick Play** | Selected from main menu | Show opponent selection (unlocked characters). Player picks opponent and difficulty. Run match. Show result. Return to Quick Play menu. | Player exits to main menu |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Board Rules Engine** | Campaign drives | Calls `start_match(mode, side_assignment)` with opponent config. Listens to `match_ended` for result (winner, move_count, pieces_remaining). |
| **AI System** | Campaign configures | Provides character ID, difficulty (with feud override), and side assignment (always Attacker). |
| **Reputation System** | Campaign feeds results | After each win, sends match result data. Reputation System calculates and returns reputation earned. Campaign checks thresholds for chapter gating. |
| **Feud System** | Bidirectional | Campaign sends match results and opponent feud tendency. Feud System returns: active feuds, injected rematches, difficulty overrides. Campaign inserts feud matches into schedule. |
| **Dialogue System** | Campaign triggers | Before and after each match, Campaign provides opponent ID, match history, feud state. Dialogue System returns appropriate text. Campaign pushes dialogue overlay. |
| **Scene Management** | Campaign drives flow | Calls `change_scene()` for campaign map → match transitions. Calls `push_overlay()` for dialogue, match result. |
| **Save System** | Campaign provides state | Exposes full campaign state for serialization: current chapter, match position, match history, unlocked opponents. Loads state on Continue. |
| **Campaign UI** | Campaign provides data | Campaign UI reads campaign state for display: chapter info, opponent list, reputation, feud status. |
| **Tutorial System** | Campaign triggers | For Prologue tutorial match, Campaign tells Tutorial System to activate guided mode. |

## Formulas

No mathematical formulas. Campaign logic is state-driven (chapter gating, match sequencing, feud injection). Reputation calculations are owned by the Reputation System. Feud state transitions are owned by the Feud System.

The only numeric check the Campaign System performs:

```
chapter_accessible = (previous_boss_defeated == true)
                 AND (current_reputation >= chapter_rep_threshold)
```

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|-------------------|-----------|
| Player defeats Chapter 1 boss but has < 15 reputation | Chapter 2 is locked. Player must replay Chapter 1 matches (no additional rep) or win feud rematches. Message: "You need more reputation to travel east." | Reputation gate prevents under-prepared players from progressing |
| Player loses to the same opponent 10+ times | No penalty, no cap. Dialogue may become more sympathetic or resigned depending on the character. Feud may escalate to Nemesis. | The game never locks the player out |
| Player reaches Chapter 4 final boss slot with < 80 reputation | Saoirse (match 17) is playable at 60 rep. Murchadh requires 80. If player has < 80 after Saoirse, they must earn more from feud rematches. | The final boss has the highest reputation gate |
| Feud System injects a rematch but the chapter has no flex slot remaining | Defer the feud to the next chapter's flex slot. If no future slots exist, the feud resolves without a rematch (opponent dialogue acknowledges the unfinished business). | Feud rematches are optional content — they shouldn't break the schedule |
| Player quits mid-match | Save System preserves campaign state (current match position). On return, player restarts the match from the beginning — mid-match state is not saved. | Simplicity — saving mid-match adds significant complexity for minimal benefit in short matches |
| Quick Play — player selects opponent they haven't unlocked | Not possible — UI only shows encountered opponents | Campaign UI enforces this |
| Player completes campaign and returns to main menu | Campaign Complete flag set. Continue shows post-campaign state. Quick Play has all opponents unlocked. New Game option available to restart. | The game has a clear ending |
| Conchobar appears in both Chapter 2 (boss) and Chapter 3 (rematch) | Different match entries with different difficulties (5 → 6). Match history tracks both encounters under the same character ID. | Returning characters are different matches, same person |
| Diarmait's guaranteed rematch — when does it fire? | Diarmait reappears in Chapter 3 regardless of result. His rematch is a fixed match, not a feud injection. | The concept specifies he comes back no matter what |

## Dependencies

| System | Direction | Nature | Interface |
|--------|-----------|--------|-----------|
| **Board Rules Engine** | This depends on | Hard — Campaign runs matches through the engine | `start_match()`, `match_ended` signal |
| **AI System** | This depends on | Hard — Campaign configures AI for each opponent | Character ID, difficulty, side assignment |
| **Reputation System** | Depends on this | Hard — Reputation needs match results from Campaign | Match result data (win/loss, move count, opponent, bonuses) |
| **Feud System** | Depends on this | Hard — Feud needs match results and opponent feud tendency | Match result, opponent profile, feud tendency |
| **Dialogue System** | Depends on this | Hard — Dialogue needs opponent ID, match history, feud state | Opponent data, match history, feud state |
| **Save System** | Depends on this | Hard — Save persists campaign state | Full campaign state object |
| **Campaign UI** | Depends on this | Hard — Campaign UI displays campaign state | Chapter info, match list, opponent data, reputation |
| **Tutorial System** | Depends on this | Soft — Tutorial activates during Prologue | Tutorial activation flag |
| **Scene Management** | This uses | Hard — Campaign drives all scene transitions | `change_scene()`, `push_overlay()`, `pop_overlay()` |

**This system depends on:** Board Rules Engine (hard), AI System (hard), Scene Management (hard).

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|--------------------|--------------------|
| `chapter_rep_thresholds` | [0, 0, 15, 35, 60] | 0–100 per chapter | Harder to advance — player must win more or earn bonuses | Easier to advance — player can progress with more losses |
| `final_boss_rep_threshold` | 80 | 60–100 | Final boss more gated — ensures player is experienced | Final boss accessible sooner |
| `feud_slots_per_chapter` | [0, 0, 1, 1, 1] | 0–2 per chapter | More feud rematches possible — longer campaign | Fewer feuds — shorter, more predictable campaign |
| `quick_play_difficulty_range` | ±1 from campaign difficulty | ±0 to ±2 | More difficulty options in Quick Play | Stricter Quick Play |
| `replay_grants_reputation` | false | true/false | Replaying gives rep (anti-frustration, but exploitable) | Replaying is purely practice |

## Acceptance Criteria

- [ ] New Game starts at Prologue with 0 reputation and clean match history
- [ ] Tutorial match runs in guided mode with Tutorial System active
- [ ] Prologue scripted loss plays as cutscene — no player input, Board Rules Engine in Scripted mode
- [ ] Chapter progression gates correctly on both boss defeat AND reputation threshold
- [ ] All 18 fixed matches play in correct order with correct opponent profiles
- [ ] Feud rematches inject into flex slots when Feud System provides them
- [ ] Flex slots fall back to default opponents when no feuds are active
- [ ] Losing a match keeps the player at the same position with changed dialogue
- [ ] Winning a match awards reputation and unlocks the next match
- [ ] Match history correctly tracks wins, losses, and move counts per opponent
- [ ] Quick Play shows only encountered opponents with adjustable difficulty
- [ ] Continue correctly loads saved campaign state
- [ ] Campaign ends with victory dialogue and credits after defeating Murchadh
- [ ] Conchobar and Caoimhe appear at correct difficulties in their second appearances
- [ ] Diarmait's guaranteed rematch appears in Chapter 3 regardless of Chapter 2 result
- [ ] Scene transitions follow correct flow: campaign map → dialogue → match → result → campaign map
- [ ] All opponent profiles loaded from external data — no hardcoded character data
- [ ] Campaign state is fully serializable for Save System

## Open Questions

| Question | Owner | Target Resolution | Resolution |
|----------|-------|-------------------|-----------|
| Should the narrator voice (between-chapter prose) be its own overlay scene, or part of the campaign map transition? | Narrative Director | Dialogue System GDD | — |
| Should the campaign track total play time per chapter for analytics or is that unnecessary for a single-player mobile game? | Game Designer | Analytics decision | — |
| Can the player replay completed chapters from the beginning, or only individual completed matches? | Game Designer | Playtesting | — |
| What happens if the player wants to abandon the campaign and start over? Confirm dialog? Separate save slot? | UX Designer | Save System GDD | — |
