# Sprint 2 — Vertical Slice

> **Status**: Active
> **Goal**: Play Prologue + Chapter 1 campaign with reputation and dialogue
> **Milestone**: Vertical Slice
> **Created**: 2026-03-29

## Sprint Goal

Build the Campaign System, Reputation System, and Dialogue System to the point
where a player can experience: Prologue (scripted loss to Murchadh) → Chapter 1
(4 matches against Seanán, Brigid, Tadhg, Fiachra) with pre/post-match dialogue,
reputation tracking, and chapter gating. This proves "does the campaign loop work?"

## What This Sprint Proves

"Does the campaign loop work?" — the Vertical Slice question from the systems
index. If playing through a short campaign with opponents who speak, reputation
that accumulates, and chapter progression that gates feels compelling, the
remaining 4 chapters are content, not architecture.

## Capacity

Solo project, session-based. Sprint 1 completed 16 tasks across ~10 sessions
(all tiers). Sprint 2 is heavier on systems integration and content authoring.

- Estimated sessions: 14
- Buffer (20%): ~3 sessions
- Available: ~11 sessions of planned work

## Tasks

### Must Have (Critical Path)

| ID | Task | System | Est. Sessions | Dependencies | Acceptance Criteria |
|----|------|--------|---------------|--------------|---------------------|
| S2-01 | **Campaign State Machine** — CampaignSystem Autoload: chapter/match tracking, linear progression, match scheduling, win/loss handling, chapter gating | Campaign | 2 | S1-complete | New game starts Prologue; matches play in order; loss keeps position; win advances; chapter boss + threshold gates next chapter |
| S2-02 | **Opponent Profiles (Ch0–Ch1)** — Create OpponentProfile + AIPersonalityData resources for tutorial opponent, Murchadh, Tadhg, Fiachra (Seanán + Brigid exist) | Campaign / AI | 0.5 | S2-01 | 6 opponent .tres files load correctly; each has correct difficulty and personality |
| S2-03 | **Campaign Match Schedule** — External data defining the Prologue + Ch1 match order (6 matches), opponent IDs, chapter assignment, boss flags | Campaign | 0.5 | S2-01, S2-02 | Schedule loads from resource; matches play in defined order |
| S2-04 | **Reputation System** — ReputationSystem Autoload: score accumulation, bonus calculation (speed/decisive/boss/rematch), tier lookup, config-driven values | Reputation | 1 | S2-01 | Win awards base 5 + applicable bonuses; loss awards 0; tier lookup correct; values from config |
| S2-05 | **Reputation Config Resource** — External config for all bonus amounts, thresholds, tier ranges | Reputation | 0.25 | S2-04 | All values externalized; no hardcoding in system code |
| S2-06 | **Dialogue Engine** — DialogueSystem Autoload: tag-based line selection with specificity cascade, context matching, fallback to generic | Dialogue | 1.5 | S2-01 | Most-specific line selected; fallback cascade never crashes; null tags match any |
| S2-07 | **Dialogue Overlay UI** — Push/pop overlay via SceneManager: character portrait placeholder, name label, text display, tap-to-advance, `dialogue_complete` signal | Dialogue | 1 | S2-06, S1-03 (SceneManager) | Overlay appears with name + text; tap advances; last tap dismisses; signal fires |
| S2-08 | **Dialogue Content (Ch0–Ch1)** — Write ~60 dialogue lines: Murchadh scripted, Seanán, Brigid, Tadhg, Fiachra (pre/post-win/post-loss × first encounter), narrator (prologue + ch1 start) | Dialogue | 1.5 | S2-06 | Every Ch0–Ch1 match has pre-match and post-match dialogue; narrator speaks at chapter transitions |
| S2-09 | **Campaign–Match Integration** — Wire CampaignSystem to launch matches: campaign map → dialogue → match → result → dialogue → reputation → campaign map | Integration | 1.5 | S2-01 through S2-08 | Full loop plays from Prologue through Ch1 without manual intervention; scene transitions smooth |
| S2-10 | **Campaign Map Screen** — Minimal campaign UI: chapter name, current opponent name/description, reputation display, "Challenge" button, chapter progress indicator | Campaign UI | 1 | S2-09 | Player sees where they are; current reputation shown; can launch next match |

### Should Have

| ID | Task | System | Est. Sessions | Dependencies | Acceptance Criteria |
|----|------|--------|---------------|--------------|---------------------|
| S2-11 | **Post-match reputation breakdown** — After match win, show reputation earned with bonus itemization before returning to campaign map | Reputation / UI | 0.5 | S2-04, S2-09 | Breakdown shows base + each bonus; total matches ReputationSystem calculation |
| S2-12 | **Retry dialogue variation** — Pre-match text changes on retry (lost_to_them + second encounter tags); post-win acknowledges the struggle | Dialogue | 0.5 | S2-08 | Losing then winning same opponent shows different dialogue than first-try win |
| S2-13 | **Prologue scripted match** — BoardRules SCRIPTED mode plays a predetermined move sequence ending in King capture; player watches, no input | Campaign / Board Rules | 1 | S2-01 | Prologue loss plays automatically; player cannot interact; result is always attacker wins |

### Nice to Have

| ID | Task | System | Est. Sessions | Dependencies | Acceptance Criteria |
|----|------|--------|---------------|--------------|---------------------|
| S2-14 | **Narrator text styling** — Distinct visual treatment for narrator lines (italic, centered, muted background) vs. opponent dialogue | Dialogue UI | 0.5 | S2-07 | Narrator visually distinct from character dialogue |
| S2-15 | **Match history tracking** — Record wins/losses/move counts per opponent; display on campaign map | Campaign | 0.5 | S2-09 | History persists across matches; viewable from campaign screen |
| S2-16 | **Quick Play mode** — Separate from campaign: choose unlocked opponent, adjustable difficulty, no reputation earned | Campaign | 0.5 | S2-02, S2-09 | Quick Play accessible from main menu; no campaign state affected |

## Carryover from Previous Sprint

None — Sprint 1 completed all tiers.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Campaign state machine complexity — many transitions between scenes, dialogue, match, result | Medium | High | Build incrementally: get basic match flow working first (S2-01 + S2-09), then layer dialogue and reputation |
| Dialogue specificity matching too complex or slow | Low | Medium | Start with simple opponent_id + timing matching; add tag depth incrementally |
| Dialogue content volume (~60 lines for Ch0–Ch1) takes longer than expected | Medium | Medium | Write minimal set first (1 pre + 1 post-win + 1 post-loss per opponent); add variety lines as Should Have |
| SceneManager overlay stack not robust enough for dialogue → match → result flow | Low | High | Test overlay push/pop sequences early; the foundation from S1-03 should handle this |
| Scripted match mode requires new BoardRules mode not yet implemented | Medium | Medium | Scope S2-13 as Should Have; can fake with auto-play AI vs AI at difficulty 7 as fallback |

## Dependencies on External Factors

- None for this sprint. All systems are internal. No external APIs, no device testing required.
- Art assets remain placeholder (colored shapes, text labels).

## Implementation Order

The dependency chain dictates build order:

```
Session 1-2:   S2-01 (Campaign State Machine — foundation for everything)
Session 3:     S2-02 + S2-03 (Opponent profiles + match schedule)
               S2-04 + S2-05 (Reputation System — parallel, only needs Campaign)
Session 4-5:   S2-06 (Dialogue Engine — needs Campaign for context)
Session 6:     S2-07 (Dialogue Overlay UI)
Session 7-8:   S2-08 (Dialogue Content writing)
Session 9-10:  S2-09 (Campaign–Match Integration — wires everything)
Session 11:    S2-10 (Campaign Map Screen)
Buffer:        S2-11 through S2-16, debugging, iteration
```

## Definition of Done for this Sprint

- [ ] All Must Have tasks (S2-01 through S2-10) completed
- [ ] Player can start a new campaign and play through Prologue + Chapter 1
- [ ] Pre-match and post-match dialogue appears for every match
- [ ] Reputation accumulates correctly and displays on campaign map
- [ ] Chapter 1 boss defeat + reputation ≥ 15 gates Chapter 2 (shown but not playable)
- [ ] Loss keeps player at same match with retry dialogue
- [ ] All opponent profiles and dialogue loaded from external data (no hardcoding)
- [ ] No crashes during normal campaign flow
- [ ] Code follows ADR-0001 architecture (Autoloads, signals, Resources)
- [ ] Design documents updated for any deviations discovered during implementation
