# Sprint 4 — Campaign UI, Tutorial & i18n Groundwork

> **Status**: Complete
> **Goal**: Polish the campaign experience — proper opponent cards, guided tutorial, and translation-ready dialogue
> **Milestone**: Alpha (completing final Alpha systems)
> **Created**: 2026-03-29

## Sprint Goal

Complete the two remaining Alpha-tier systems (Campaign UI and Tutorial) and lay
the groundwork for future localization. The campaign map becomes a proper opponent
card list with feud indicators and reputation progress. New players get a guided
first match. Dialogue JSON gains translation keys without breaking existing flow.

## What This Sprint Proves

"Is the full Alpha experience complete?" Campaign UI polish makes the progression
visible and satisfying. The tutorial makes the game accessible to new players.
i18n groundwork ensures we don't have to restructure later.

## Capacity

Solo project, session-based. Sprint 3: 17 tasks across ~6 sessions (velocity
continues to increase). Targeting ~16 tasks.

- Estimated sessions: 10
- Buffer (20%): ~2 sessions
- Available: ~8 sessions of planned work

## Tasks

### Must Have (Critical Path)

| ID | Task | System | Est. Sessions | Dependencies | Acceptance Criteria |
|----|------|--------|---------------|--------------|---------------------|
| S4-01 | **Campaign UI — opponent cards** — Replace text labels with proper card layout: portrait placeholder, name, title, status indicator. 6 card states: Upcoming (dimmed), Active (glow), Won, Lost-then-Won, Feud, Nemesis | Campaign UI | 1.5 | — | Each card state visually distinct; active card tappable; upcoming cards dimmed and not tappable |
| S4-02 | **Campaign UI — reputation bar** — Progress bar showing current rep → next threshold. Tier label, current score, next threshold text. Bar animates on rep change | Campaign UI | 0.5 | — | Bar fills proportionally; tier label updates; animation plays after match result |
| S4-03 | **Campaign UI — chapter navigation** — Dot indicators at bottom: current (highlighted), completed (tappable for review), future (locked with threshold). Chapter transition fades 0.4s | Campaign UI | 0.5 | S4-01 | Dots render for all chapters; completed chapters reviewable; locked chapters show threshold |
| S4-04 | **Campaign UI — feud indicators** — Visual markers on opponent cards for In Feud (flame/icon), Nemesis (skull/icon), Feud Resolved (checkmark). Feud Pending NOT visible | Campaign UI | 0.5 | S4-01 | Feud/Nemesis/Resolved states show correct indicator; Pending shows nothing |
| S4-05 | **Campaign UI — match summary** — Tapping completed card shows win indicator and brief result. Scrollable match list with fixed header when content exceeds screen | Campaign UI | 0.5 | S4-01 | Completed cards tappable; summary displays; list scrolls with fixed header |
| S4-06 | **Campaign UI — responsive layout** — 44pt minimum tap targets. Layout adapts to small phone (720x1280), large phone, tablet. Test at multiple viewport sizes | Campaign UI | 0.5 | S4-01 | All tap targets ≥ 44pt; no overlap or clipping at 720x1280; scales up cleanly |
| S4-07 | **Tutorial — data file** — External JSON for tutorial steps: board layout, piece positions, allowed pieces, forced highlights, scripted AI moves, narrator text. 8 steps per GDD | Tutorial | 0.5 | — | JSON loads and validates; all 8 steps defined with positions, moves, and text |
| S4-08 | **Tutorial — core system** — TutorialSystem node: loads data, constrains input (allowed pieces + forced highlights), submits scripted AI moves, tracks step progression. Deactivates after step 8 | Tutorial | 1.5 | S4-07 | Steps advance correctly; only allowed pieces interactive; AI moves execute; tutorial_complete signal fires |
| S4-09 | **Tutorial — board integration** — Board UI respects tutorial constraints: dimmed non-allowed pieces, forced highlight cells, scripted AI move animation identical to normal | Tutorial | 1 | S4-08 | Dimming visible; forced highlights show; AI moves animate normally; no input on non-allowed pieces |
| S4-10 | **Tutorial — campaign hook** — Tutorial activates only on Prologue match 1. Campaign System proceeds to Prologue match 2 after tutorial_complete. Tutorial not skippable, not saved | Tutorial | 0.5 | S4-08, S4-09 | Tutorial fires on first match only; campaign advances after; restarting campaign replays tutorial |

### Should Have

| ID | Task | System | Est. Sessions | Dependencies | Acceptance Criteria |
|----|------|--------|---------------|--------------|---------------------|
| S4-11 | **i18n — dialogue key restructure** — Add `textKey` field to all dialogue entries. Key format: `dialogue.[id]`. Keep `text` as English default. Create `assets/data/locales/en.json` with all keys mapped | i18n | 0.5 | — | Every dialogue entry has textKey; en.json contains all keys; existing text field unchanged |
| S4-12 | **i18n — speaker key restructure** — Add `speakerKey` to dialogue entries. Speaker names in locale file. Opponent profile names also keyed | i18n | 0.25 | S4-11 | Speaker names localizable; opponent profile names have keys |
| S4-13 | **i18n — display integration** — DialogueOverlay resolves text via locale lookup with fallback to `text` field. UI strings (buttons, labels) extracted to locale file | i18n | 0.5 | S4-11 | Dialogue displays from locale file; missing keys fall back to text field; UI labels localizable |
| S4-14 | **Dialogue phrasing pass** — Review all 46 dialogue lines for stronger Irish speech patterns: Hiberno-English fronting, indirectness, concrete imagery, understatement. Maintain each character's voice | Narrative | 0.5 | — | Dialogue reviewed; phrasing more distinctly Irish; character voices preserved |

### Nice to Have

| ID | Task | System | Est. Sessions | Dependencies | Acceptance Criteria |
|----|------|--------|---------------|--------------|---------------------|
| S4-15 | **Tutorial — narrator styling** — Tutorial narrator text uses same italic/centered narrator style from dialogue system. Tap to advance between steps | Tutorial / UI | 0.25 | S4-08 | Narrator text styled consistently; tap advances; no visual glitches |
| S4-16 | **Test coverage — TutorialSystem** — Unit tests for step progression, input constraints, scripted AI moves, completion signal | Testing | 0.5 | S4-08 | All tutorial steps tested; constraint logic verified; signal emission confirmed |

## Carryover from Previous Sprint

None — Sprint 3 completed all tiers.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Campaign UI refactor breaks existing campaign flow | Medium | High | Run existing campaign tests after each UI change; verify with MCP autoplay |
| Tutorial input constraints conflict with Board UI event handling | Medium | Medium | Tutorial system sets constraints before match starts; Board UI checks constraints on input |
| i18n key restructure breaks dialogue matching | Low | High | Keep `text` field as-is; locale is additive; test dialogue matching after key addition |
| Dialogue phrasing changes alter character voice inconsistently | Low | Medium | Review all lines for each character as a group; maintain voice notes |

## Dependencies on External Factors

- None. All systems are internal.
- Art assets remain placeholder (colored shapes, text labels).
- No real locale translations needed yet — just the key structure.

## Implementation Order

```
Session 1:     S4-07 (Tutorial data file — foundation)
               S4-14 (Dialogue phrasing pass — independent)
Session 2-3:   S4-01 (Opponent cards — biggest UI task)
Session 4:     S4-02 + S4-04 (Reputation bar + feud indicators)
Session 5:     S4-03 + S4-05 + S4-06 (Chapter nav + match summary + responsive)
Session 6-7:   S4-08 (Tutorial core system)
Session 8:     S4-09 + S4-10 (Tutorial board integration + campaign hook)
Session 9:     S4-11 + S4-12 (i18n key restructure)
Session 10:    S4-13 (i18n display integration)
Buffer:        S4-15, S4-16
```

## Definition of Done for this Sprint

- [x] All Must Have tasks (S4-01 through S4-10) completed
- [x] Campaign map shows proper opponent cards with all 6 states
- [x] Reputation bar displays and animates correctly
- [x] Chapter navigation dots work (review completed, locked future)
- [x] Feud indicators visible on appropriate cards
- [x] Tutorial plays through 8 steps on Prologue match 1
- [x] Tutorial constrains input correctly (only allowed pieces)
- [x] Tutorial completes and campaign advances to match 2
- [x] All existing tests still pass (247 tests, 1 pre-existing failure)
- [x] No crashes during campaign flow, tutorial, or save/load
- [x] Code follows ADR-0001 architecture
- [x] S4-11 + S4-12 + S4-13: i18n system with LocaleSystem, textKey/speakerKey, en.json
- [x] S4-15: Tutorial narrator styling (uses existing DialogueOverlay narrator path)
- [x] S4-16: Tutorial unit tests (17 tests)
- [x] S4-14: Dialogue phrasing pass — Hiberno-English strengthening across all 46 lines
