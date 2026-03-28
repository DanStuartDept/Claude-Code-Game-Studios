# Feud System

> **Status**: Designed
> **Author**: user + game-designer
> **Last Updated**: 2026-03-28
> **Implements Pillar**: Narrative — feuds make opponents feel like real people who remember you

## Overview

The Feud System tracks personal rivalries between the player and individual opponents. When the player loses to an opponent with a high feud tendency — or when certain story conditions are met — the system escalates the relationship from Neutral through a series of rivalry states: Feud Pending, In Feud, Feud Resolved, or Nemesis. An active feud causes the opponent to reappear later in the campaign at increased difficulty, with hostile dialogue and a reputation bonus on the line. The system is a state machine per opponent, driven by match results and feud tendency values. It does not own dialogue, difficulty, or scheduling — it provides feud state to the Campaign System (which injects rematches into flex slots), the AI System (which raises difficulty by +1), the Dialogue System (which selects feud-appropriate lines), and the Reputation System (which awards feud and nemesis bonuses). The Feud System makes the campaign feel personal: without it, opponents are a sequence of difficulty tiers. With it, they are people who remember what happened.

## Player Fantasy

The player should feel hunted. When a feud activates, the opponent is no longer behind them — they're ahead, waiting, and angry. The pre-match dialogue shifts. The stakes shift. Winning a feud match should feel like settling a debt — satisfying, earned, and final. Losing one should feel like the debt getting heavier. A nemesis should feel like a shadow the player has been carrying for chapters — someone they've failed against three times, whose name makes them tense. Clearing a nemesis should be one of the most satisfying moments in the campaign, second only to the Murchadh rematch. Feuds are not a punishment for losing — they are the game's way of saying "this one isn't finished yet." The player should want to resolve them, not avoid them.

## Detailed Design

### Core Rules

#### 1. Feud State Machine

Each opponent has an independent feud state. The system tracks one state per `opponent_id`.

| State | Description |
|-------|-------------|
| **Neutral** | No rivalry. Default state for all opponents at campaign start. |
| **Feud Pending** | A loss has been flagged. The feud will activate when a rematch slot is available in a future chapter. |
| **In Feud** | Active rivalry. A rematch has been injected into the campaign schedule. Opponent appears at +1 difficulty with hostile dialogue. |
| **Feud Resolved** | Player won the feud rematch. Rivalry is settled. Opponent's dialogue shifts to grudging respect. Terminal state. |
| **Nemesis** | Player has lost encounters to this opponent 3+ times across separate match slots. Maximum hostility. Opponent appears at +1 difficulty (same as In Feud). Winning clears to Feud Resolved. Terminal once resolved. |

#### 2. State Transitions

```
Neutral ──[feud triggered]──► Feud Pending
Feud Pending ──[rematch slot reached]──► In Feud
In Feud ──[player wins rematch]──► Feud Resolved
In Feud ──[player loses rematch]──► In Feud (loss count increments)
In Feud ──[loss count reaches nemesis_threshold]──► Nemesis
Nemesis ──[player wins]──► Feud Resolved
Nemesis ──[player loses]──► Nemesis (stays — cannot escalate further)
```

No state ever transitions backward. Feud Resolved is permanent — a resolved feud cannot reignite.

#### 3. Feud Triggers

A feud is triggered when ALL of these conditions are met:

| Condition | Description |
|-----------|-------------|
| Player lost the encounter | The player lost at least once during this match slot (retries that end in a win still count the loss) |
| Opponent has feud tendency > 0 | The `feud_tendency` value from the opponent profile is checked |
| Feud roll succeeds | Random roll: `random() < feud_tendency`. Higher tendency = more likely. |
| Opponent is currently Neutral | An opponent already in Feud Pending, In Feud, or Nemesis cannot trigger a new feud |
| Opponent is not in a terminal state | Feud Resolved opponents cannot re-enter the feud pipeline |

If the feud roll succeeds, the opponent transitions from Neutral → Feud Pending.

#### 4. Feud Tendency Values

Feud tendency is a float (0.0–1.0) defined per opponent in the Campaign System's opponent profiles.

| Opponent | Feud Tendency | Likelihood | Rationale |
|----------|--------------|------------|-----------|
| Séanán na Farraige | 0.1 | Very low | He doesn't hold grudges |
| Brigid na Scailpe | 0.2 | Low | Stoic — she moves on |
| Tadhg an Ósta | 0.8 | Very high | Boastful, proud — most likely feud |
| Fiachra an Fhánaí | 0.4 | Moderate | Chapter 1 boss — curious, not hostile |
| Orlaith na gCros | 0.2 | Low | Composed, academic |
| Diarmait Óg | 0.0 | N/A | Guaranteed rematch is a fixed campaign slot, not a feud |
| Caoimhe an Léinn | 0.3 | Moderate | Intellectual — not personal but she remembers |
| Conchobar Críonna | 0.0 | N/A | Fixed rematch in Chapter 3 — campaign-driven, not feud-driven |
| Eithne an Chiúin | 0.1 | Very low | She says nothing — her grudges are invisible |
| Ruairí an Bhaird | 0.15 | Low | Cheerful — he'd rather sing about it than fight |
| Niall na Naoi gCailleadh | 0.3 | Moderate | He respects loss, but he also respects persistence |
| Saoirse na Cúirte | 0.2 | Low | Professional — she's evaluating, not feuding |
| Murchadh mac Fáelán | 0.0 | N/A | Final boss — his rematch is the entire campaign, not a feud |

Characters with 0.0 feud tendency (Diarmait, Conchobar, Murchadh) cannot enter the feud pipeline. Their rematches are fixed campaign events.

#### 5. Loss Counting

Losses are counted per opponent across *separate match slots*, not retries within the same slot:

- Player loses to Tadhg in Chapter 1 (match slot 5), retries 3 times, then wins → **1 encounter loss** recorded
- Tadhg reappears as a feud rematch in Chapter 3, player loses again → **2 encounter losses** total
- If Tadhg appeared again and the player lost → **3 encounter losses** → Nemesis threshold reached

Retries within the same match slot do not increment the encounter loss count.

#### 6. Nemesis Escalation

When an opponent In Feud accumulates `nemesis_threshold` (default: 3) encounter losses, they escalate to Nemesis:

- Nemesis uses the same +1 difficulty as In Feud (no additional increase)
- Nemesis dialogue is distinct — cold, final, acknowledging the long history
- Winning against a Nemesis awards the nemesis reputation bonus (+5) in addition to the feud bonus (+3)
- Nemesis is the highest escalation — losing to a Nemesis does not escalate further

#### 7. Feud Rematches — Injection Into Campaign

When an opponent is In Feud or Nemesis and the campaign reaches a chapter with an available feud injection slot:

1. The Feud System reports active feuds to the Campaign System
2. The Campaign System fills the chapter's flex slot with the feuding opponent
3. If multiple feuds are active, the oldest feud (earliest trigger) takes priority
4. If no flex slot is available in the current chapter, the feud carries to the next chapter's slot
5. If no future slots remain (Chapter 4 flex slot is the last), the feud resolves without a rematch — dialogue acknowledges unfinished business

Only one feud rematch per chapter. A player can have at most one active feud match per chapter.

#### 8. Feud Difficulty Override

When a feud rematch fires:

- The AI System receives the opponent's base difficulty +1 (capped at 7)
- This override is provided by the Feud System as part of the feud context
- Example: Tadhg (base difficulty 2) appears as a feud rematch at difficulty 3

#### 9. Characters Exempt From Feuds

Three characters have fixed rematches managed by the Campaign System, not the Feud System:

| Character | Rematch Type | Reason |
|-----------|-------------|--------|
| Diarmait Óg | Fixed in Chapter 3 | Concept specifies guaranteed rematch regardless of result |
| Conchobar Críonna | Fixed in Chapter 3 | Chapter 2 boss returning at higher difficulty — campaign structure |
| Murchadh mac Fáelán | Fixed in Chapter 4 | The entire campaign is the rematch |

These characters have `feud_tendency: 0.0` and never enter the feud state machine. Their rematches are part of the fixed match schedule.

### States and Transitions

| State | Entry Condition | Behavior | Exit Condition |
|-------|----------------|----------|----------------|
| **Neutral** | Campaign start (default for all opponents) | No feud effects. Opponent plays at base difficulty with neutral dialogue. | Feud trigger succeeds after a loss |
| **Feud Pending** | Feud roll succeeded (`random() < feud_tendency`) after player lost an encounter | Feud is flagged but not yet active. No gameplay effect until a rematch slot is reached. State is persisted by Save System. | Campaign reaches a chapter with an available feud injection slot |
| **In Feud** | Campaign System activates the feud rematch in a flex slot | Opponent appears at base difficulty +1 (cap 7). Dialogue System receives `feud_state: "in_feud"`. Reputation System will award feud bonus (+3) on win. | Player wins (→ Feud Resolved) or encounter loss count reaches nemesis_threshold (→ Nemesis) |
| **Nemesis** | Encounter loss count reaches `nemesis_threshold` (3) while In Feud | Same difficulty override as In Feud (+1). Dialogue System receives `feud_state: "nemesis"`. Reputation System awards both feud (+3) and nemesis (+5) bonuses on win. Carries forward to next available flex slot if not resolved. | Player wins (→ Feud Resolved) |
| **Feud Resolved** | Player wins a feud rematch or nemesis rematch | Terminal state. Dialogue System receives `feud_state: "feud_resolved"`. No further feud effects. Opponent returns to base difficulty if encountered again. | None — permanent |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Campaign System** | Campaign feeds match results | After each match, Campaign calls `process_match_result(opponent_id, player_won, match_slot_id)`. Feud System returns: feud state change (if any), active feuds list. Campaign calls `get_active_feuds()` when entering a new chapter to fill flex slots. Campaign calls `get_feud_state(opponent_id)` to pass feud context to Dialogue and AI. |
| **AI System** | Feud provides difficulty override | AI System calls `get_difficulty_override(opponent_id)` before configuring an opponent. Returns base difficulty +1 if In Feud or Nemesis, base difficulty otherwise. Capped at 7. |
| **Reputation System** | Feud provides bonus flags | Campaign passes `is_feud_win` and `is_nemesis_win` flags (sourced from Feud System) to Reputation System's `award_reputation()`. Feud System does not call Reputation directly — Campaign mediates. |
| **Dialogue System** | Feud provides state tag | Campaign passes `feud_state` (neutral, feud_pending, in_feud, feud_resolved, nemesis) as part of dialogue context. Dialogue System reads the tag for line selection. Feud System does not call Dialogue directly — Campaign mediates. |
| **Save System** | Save persists feud state | Feud System exposes `get_all_feud_data()` for serialization: per-opponent feud state, encounter loss counts, pending feuds. Save System calls `load_feud_data(data)` on Continue. |
| **Campaign UI** | UI reads feud status | Campaign UI calls `get_feud_state(opponent_id)` to display rivalry indicators on the campaign map (e.g., a feud icon next to an opponent's portrait). |

## Formulas

### Feud Trigger Roll

```
feud_triggered = (player_lost_encounter == true)
             AND (opponent.feud_tendency > 0.0)
             AND (current_feud_state == "neutral")
             AND (random() < opponent.feud_tendency)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `player_lost_encounter` | bool | — | Campaign System | Whether the player lost at least once during this match slot |
| `feud_tendency` | float | 0.0–1.0 | Opponent profile | Probability of triggering a feud on loss |
| `current_feud_state` | string | enum | Feud System | Opponent's current feud state — must be Neutral |
| `random()` | float | 0.0–1.0 | RNG | Uniform random roll |

**Expected feud rates per campaign playthrough:**
- A player who loses to every opponent once: Tadhg (80%), Fiachra (40%), Caoimhe (30%), Niall (30%) are the most likely feuds. Expected ~1–2 feuds per playthrough.
- A player who wins every match without losing: 0 feuds (no losses = no triggers).
- A player who loses frequently: more feuds, but capped by available flex slots (3 total across Chapters 2–4).

### Difficulty Override

```
effective_difficulty = min(opponent.base_difficulty + feud_difficulty_bonus, max_difficulty)
```

| Variable | Type | Value | Source | Description |
|----------|------|-------|--------|-------------|
| `base_difficulty` | int | 1–7 | Opponent profile | Opponent's standard difficulty |
| `feud_difficulty_bonus` | int | 1 | Config | Difficulty increase during feud/nemesis |
| `max_difficulty` | int | 7 | Config | Difficulty cap |

### Nemesis Threshold Check

```
is_nemesis = (feud_state == "in_feud")
         AND (encounter_loss_count >= nemesis_threshold)
```

| Variable | Type | Value | Source | Description |
|----------|------|-------|--------|-------------|
| `encounter_loss_count` | int | 0+ | Feud System | Number of separate match slots where the player lost to this opponent |
| `nemesis_threshold` | int | 3 | Config | Losses required for nemesis escalation |

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|-------------------|-----------|
| Player loses to Tadhg but wins on retry | Loss is still recorded for feud purposes. Feud roll happens using Tadhg's 0.8 tendency. If triggered, Tadhg enters Feud Pending. | A win after a loss doesn't erase the loss — the opponent remembers |
| Two feuds are pending when a chapter with one flex slot is entered | The oldest feud (earliest trigger) gets the slot. The other carries to the next chapter's flex slot. | First-in, first-served prevents feud stacking from overwhelming the campaign |
| Three feuds are pending but only one flex slot remains in the entire campaign | One feud gets the Chapter 4 slot. The other two resolve without rematches — dialogue acknowledges unfinished business, feud state moves to Feud Resolved with a flag marking it as "unresolved by timeout." | Feuds should never break the campaign schedule |
| Player loses to an opponent already In Feud (during the feud rematch) | Encounter loss count increments. If it reaches nemesis_threshold (3), state transitions to Nemesis. The opponent carries forward to the next flex slot. | Losing a feud rematch deepens the rivalry |
| Player loses to a Nemesis | State stays Nemesis. Loss count increments but has no further mechanical effect. Opponent carries to next flex slot. | Nemesis is the ceiling — no further escalation |
| Opponent at difficulty 7 enters a feud | Difficulty override: min(7 + 1, 7) = 7. No difficulty increase — they're already at max. Feud still affects dialogue and reputation bonuses. | Difficulty cap prevents impossible opponents |
| Feud triggers for an opponent the player never encounters again | Feud stays Pending indefinitely. If no flex slot ever activates it, it resolves as "unresolved by timeout" when the campaign ends. | Pending feuds are harmless — they only matter if a slot exists |
| Player starts a New Game | All feud states reset to Neutral. All encounter loss counts reset to 0. | Clean slate for a new campaign |
| Diarmait's guaranteed rematch — does it interact with feuds? | No. Diarmait has `feud_tendency: 0.0`. His Chapter 3 appearance is a fixed campaign match, not a feud injection. The Feud System ignores him entirely. | Fixed rematches and feuds are separate systems |
| Eithne triggers a feud (0.1 chance) | Extremely unlikely but possible. If triggered, she appears in a flex slot with +1 difficulty. Dialogue System still uses narrator lines for her (she doesn't speak). Narrator text acknowledges the feud. | Even silent opponents can hold grudges — the narrator carries it |
| Feud roll happens but feud_tendency is exactly 0.0 | Roll is skipped entirely — the condition `feud_tendency > 0.0` fails before the random roll. | Zero means zero, not "almost zero" |
| Save/load mid-feud | All feud state is persisted: per-opponent state, encounter loss counts, pending feuds. Loading restores exact feud state. | Feuds span multiple chapters — they must survive save/load |

## Dependencies

| System | Direction | Nature | Interface |
|--------|-----------|--------|-----------|
| **Campaign System** | This depends on | Hard — Campaign provides match results that drive all feud state changes | `process_match_result(opponent_id, player_won, match_slot_id)`, `get_active_feuds()`, `get_feud_state(opponent_id)` |
| **Reputation System** | Depends on this | Soft — Reputation receives feud/nemesis bonus flags via Campaign | `is_feud_win`, `is_nemesis_win` flags passed through Campaign's `award_reputation()` |
| **Dialogue System** | Depends on this | Soft — Dialogue reads feud state tag for line selection via Campaign | `feud_state` tag in dialogue context |
| **AI System** | Depends on this | Soft — AI reads difficulty override for feud opponents | `get_difficulty_override(opponent_id)` |
| **Save System** | Depends on this | Hard — Save persists all feud data across sessions | `get_all_feud_data()`, `load_feud_data(data)` |
| **Campaign UI** | Depends on this | Soft — Campaign UI displays feud indicators | `get_feud_state(opponent_id)` |

**This system depends on:** Campaign System (hard).

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|--------------------|--------------------|
| `feud_tendency` (per opponent) | 0.0–0.8 | 0.0–1.0 | More feuds trigger — campaign feels more reactive and hostile | Fewer feuds — campaign feels more predictable and calm |
| `feud_difficulty_bonus` | 1 | 0–2 | Feud rematches are harder — more punishing but more rewarding | Feud rematches feel similar to the original — less dramatic |
| `nemesis_threshold` | 3 | 2–5 | Nemesis is harder to reach — fewer nemesis moments per campaign | Nemesis triggers faster — more dramatic but less earned |
| `max_difficulty` | 7 | 5–10 | Higher cap allows feud bonus to always apply | Lower cap means more opponents hit the ceiling during feuds |
| `feud_slots_per_chapter` | [0, 0, 1, 1, 1] | 0–2 per chapter | More feud rematches possible — longer, more dynamic campaign | Fewer feuds can fire — more predictable pacing |
| `feud_priority_rule` | oldest first | oldest / highest_tendency / random | Oldest: predictable queue. Highest tendency: dramatic opponents prioritized. Random: surprise element. | N/A — this is a rule, not a scalar |
| `unresolved_feud_behavior` | resolve as timeout | timeout / carry_to_postgame / ignore | Timeout: clean ending. Carry: post-campaign content. Ignore: silent discard. | N/A — this is a rule, not a scalar |

**Critical interaction:** `feud_tendency` values × number of losses determines how many feuds a struggling player accumulates. With 3 flex slots total and Tadhg at 0.8, a player who loses to many opponents will almost certainly have at least one feud. Raising tendencies above 0.5 for multiple characters risks slot contention — monitor during playtesting.

## Acceptance Criteria

- [ ] All opponents start at Neutral feud state in a new campaign
- [ ] Feud triggers correctly when player loses and feud roll succeeds (`random() < feud_tendency`)
- [ ] Feud does not trigger for opponents with `feud_tendency: 0.0`
- [ ] Feud does not trigger for opponents already in Feud Pending, In Feud, Nemesis, or Feud Resolved
- [ ] Retries within the same match slot do not increment encounter loss count
- [ ] Losses across separate match slots correctly increment encounter loss count
- [ ] Feud Pending transitions to In Feud when Campaign activates a flex slot
- [ ] Oldest pending feud gets priority when multiple feuds compete for one slot
- [ ] Feud rematches apply +1 difficulty (capped at 7)
- [ ] Winning a feud rematch transitions to Feud Resolved (permanent)
- [ ] Losing a feud rematch increments loss count; nemesis threshold (3) triggers Nemesis state
- [ ] Nemesis state awards both feud (+3) and nemesis (+5) reputation bonuses on win
- [ ] Nemesis does not escalate further on additional losses
- [ ] Feuds with no remaining flex slots resolve as timeout with appropriate dialogue flag
- [ ] Feud Resolved is permanent — resolved opponents cannot re-enter the feud pipeline
- [ ] Diarmait, Conchobar, and Murchadh are exempt from the feud system (fixed rematches only)
- [ ] All feud data persists correctly through Save/Load (states, loss counts, pending feuds)
- [ ] New Game resets all feud states to Neutral and all loss counts to 0
- [ ] All feud tendency values and thresholds loaded from external config — no hardcoded values

## Open Questions

| Question | Owner | Target Resolution | Resolution |
|----------|-------|-------------------|-----------|
| Should the player be notified when a feud triggers ("Tadhg will remember this") or should it be silent until the rematch appears? | UX Designer | Campaign UI GDD | — |
| Should unresolved feuds (timeout) count as wins or losses for dialogue tone? Currently flagged as "unresolved by timeout" — dialogue needs to handle this third state. | Narrative Director | Dialogue content phase | — |
| Can a feud rematch appear in the same chapter as the original loss, or only in later chapters? Current design assumes later chapters only (flex slots are Ch2–4). | Game Designer | Playtesting | — |
| Should the feud roll use a seeded RNG (deterministic per save) or true random? Seeded means the same playthrough always triggers the same feuds on reload. | Game Designer | Implementation | — |
| How should Campaign UI visually indicate feud status on the campaign map? Icon overlay, colour change, portrait treatment? | Art Director | Campaign UI GDD | — |
