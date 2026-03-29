# Sprint 5 — Content Expansion & End-to-End Playability

> **Status**: Draft
> **Goal**: Fill chapters 2-4 with opponents/dialogue, implement audio system, add settings — make the full campaign playable start to finish
> **Milestone**: Beta (feature-complete, content-complete)
> **Created**: 2026-03-29

## Sprint Goal

The Alpha systems are built. Sprint 5 shifts from system-building to content
creation and final system gaps. By the end, a player can start the tutorial,
lose the scripted Prologue match, travel through all 5 chapters, face the
final boss, and hear the game. No placeholder screens, no empty chapters.

## What This Sprint Proves

"Can someone play the full game?" Every chapter has opponents. Every opponent
has dialogue. The audio system provides atmosphere. Settings let players
adjust their experience. The campaign has a complete arc from disgrace to return.

## Capacity

Solo project, session-based. Sprint 4: 16 tasks across ~3 sessions (velocity
increasing with established patterns). Targeting ~16 tasks across ~10 sessions.

- Estimated sessions: 12
- Buffer (20%): ~2 sessions
- Available: ~10 sessions of planned work

## Tasks

### Must Have (Critical Path)

| ID | Task | System | Est. Sessions | Dependencies | Acceptance Criteria |
|----|------|--------|---------------|--------------|---------------------|
| S5-01 | **Chapters 2-4 opponent profiles** — Create 8-10 new opponent .tres resources. Each has distinct name, personality, difficulty curve (ch2: 2-3, ch3: 3-4, ch4: 4-5+), feud_tendency. Character voice notes for dialogue | Narrative / Data | 1 | — | All profiles load; difficulty increases across chapters; each character has a documented voice |
| S5-02 | **Chapters 2-4 campaign schedule** — Populate campaign_schedule.json with ~12 matches: 3 standard + 1 boss per chapter (ch2, ch3, ch4). Final boss is Murchadh rematch (ch4) | Campaign | 0.5 | S5-01 | Schedule loads; all matches accessible; chapter gating works with rep thresholds |
| S5-03 | **Chapters 2-4 dialogue — ch2 The Old Roads** — Pre/post-win/post-loss/retry + feud/nemesis lines for ch2 opponents (~20 lines). Hiberno-English voice. Add to dialogue_lines.json + en.json | Narrative | 1 | S5-01 | All dialogue contexts fire correctly; phrasing matches character voice |
| S5-04 | **Chapters 2-4 dialogue — ch3 The Midlands** — Same scope as S5-03 for ch3 opponents | Narrative | 1 | S5-01 | Same as S5-03 |
| S5-05 | **Chapters 2-4 dialogue — ch4 The Return** — Same scope for ch4 opponents + Murchadh rematch dialogue (new lines for returning as a stronger player) | Narrative | 1 | S5-01 | Same as S5-03; Murchadh rematch lines reflect player's journey |
| S5-06 | **Chapter narrator transitions** — Narrator text for entering ch2, ch3, ch4, and post-ch4 (victory epilogue). Road descriptions, stakes escalation. Triggered on advance_chapter | Narrative / Campaign | 0.5 | S5-02 | Narrator text shows between chapters; each has distinct tone/location |
| S5-07 | **Audio system core** — AudioSystem autoload per design/gdd/audio-system.md. Three buses (Music, SFX, Ambient). play_sfx(event_id), play_music(track_id), crossfade support. No real assets — uses placeholder beeps/tones | Audio | 1.5 | — | AudioSystem loads; buses configured; play/stop/crossfade methods work; placeholder sounds audible |
| S5-08 | **Board sound events** — Connect BoardRules signals to AudioSystem: piece_moved, piece_captured, king_threatened, match_ended, turn_changed. Piece select/deselect from BoardUI | Audio / Board | 0.5 | S5-07 | Every board action triggers correct sound event; sounds don't overlap badly |
| S5-09 | **Scene music & ambient** — Music mapping per scene/chapter. Campaign map plays chapter ambient. Match plays chapter tension track. Crossfade on scene change. Dialogue overlay ducks music | Audio / Scenes | 0.5 | S5-07 | Music changes with scene; chapter ambient plays; dialogue ducks correctly |

### Should Have

| ID | Task | System | Est. Sessions | Dependencies | Acceptance Criteria |
|----|------|--------|---------------|--------------|---------------------|
| S5-10 | **Settings screen** — Accessible from main menu and campaign map. Volume sliders (master, music, sfx, ambient). Text size toggle (normal/large). Colorblind mode flag. Persist via SaveSystem | UI / Settings | 1 | S5-07 | Settings screen opens; sliders control volume; preferences persist across sessions |
| S5-11 | **Campaign completion flow** — Victory narrator text after final boss win. Campaign map shows completion state. Option to return to main menu or start new campaign | Campaign / UI | 0.5 | S5-05 | Victory text displays; campaign_completed signal fires; UI reflects completion |
| S5-12 | **Full campaign integration test** — Autoplay through all 5 chapters start to finish. Verify: tutorial, scripted loss, all chapter transitions, boss gates, rep thresholds, final boss, completion | Testing | 0.5 | S5-02, S5-06 | Autoplay completes full campaign without crashes; all transitions fire |
| S5-13 | **Save/load round-trip with new chapters** — Save mid-campaign (ch3), reload, verify all state: match history, reputation, feud states, chapter position. Test with new opponent IDs | Testing | 0.5 | S5-02 | Save/load preserves all state; new opponent IDs serialize correctly |

### Nice to Have

| ID | Task | System | Est. Sessions | Dependencies | Acceptance Criteria |
|----|------|--------|---------------|--------------|---------------------|
| S5-14 | **ADR-0002: Audio architecture** — Document audio system decisions: bus layout, event-driven wiring, placeholder strategy, asset pipeline plan | Docs | 0.25 | S5-07 | ADR written and linked from technical-preferences.md |
| S5-15 | **Fix pre-existing test failure** — Investigate and fix test_input_blocked_during_animation in test_board_input.gd | Testing | 0.25 | — | Test passes; no regressions |
| S5-16 | **Narrator text for chapter 1 completion** — Currently ch1 has start/end narrator text but no mid-chapter beats. Add 1-2 narrator lines for after beating Fiachra | Narrative | 0.25 | — | Narrator text fires after ch1 boss; phrasing consistent |

## Content Design Notes

### Opponent Design Philosophy

Each chapter introduces opponents who teach the player something:

- **Ch1 Connacht** (done): Basics — open play, patience, aggression, reading opponents
- **Ch2 The Old Roads**: Midgame — traps, sacrifices, positional play. Characters are road-worn, pragmatic
- **Ch3 The Midlands**: Mastery — deep calculation, psychological pressure. Characters are established, respected
- **Ch4 The Return**: Peak — opponents who know the player's reputation. Murchadh rematch is the test of everything learned

### Difficulty Curve

| Chapter | Opponent Difficulty | AI Depth | Notes |
|---------|-------------------|----------|-------|
| 0 (Prologue) | Tutorial / 7 (scripted) | 1 / 3 | Tutorial is guided; scripted loss is fixed |
| 1 (Connacht) | 1, 2, 2, 3 | 1-3 | Gentle ramp |
| 2 (Old Roads) | 2, 3, 3, 4 | 2-3 | Noticeable step up |
| 3 (Midlands) | 3, 4, 4, 5 | 3-4 | Challenging |
| 4 (Return) | 4, 5, 5, 7 | 3-5 | Murchadh at max |

### Reputation Thresholds (from campaign_schedule.json)

| Chapter | Threshold | Approx matches needed |
|---------|-----------|----------------------|
| Ch1 | 0 | Auto after prologue |
| Ch2 | 15 | ~3-4 wins |
| Ch3 | 35 | ~6-8 wins total |
| Ch4 | 60 | ~12-15 wins total |

## Carryover from Previous Sprint

None — Sprint 4 completed all tiers.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| 8-10 new opponents makes dialogue volume very large (~200 lines) | High | Medium | Batch dialogue writing with background agents; write per-chapter |
| Audio placeholder sounds may be annoying during testing | Low | Low | Keep placeholder volumes low; add mute option early |
| Chapter 4 Murchadh rematch needs unique feel vs. Prologue scripted match | Medium | Medium | Different match_type (standard, not scripted); unique dialogue referencing journey |
| Rep threshold gating may feel grindy if set too high | Medium | High | Playtest full campaign via autoplay; adjust thresholds based on average rep per win |

## Implementation Order

```
Session 1:      S5-01 (Opponent profiles — foundation for everything)
Session 2:      S5-02 (Campaign schedule) + S5-06 (Chapter transitions)
Session 3-4:    S5-03 (Ch2 dialogue)
Session 5:      S5-04 (Ch3 dialogue)
Session 6:      S5-05 (Ch4 + Murchadh dialogue)
Session 7-8:    S5-07 (Audio system core)
Session 9:      S5-08 + S5-09 (Board sounds + scene music)
Session 10:     S5-10 (Settings screen)
Buffer:         S5-11 through S5-16
```

## Definition of Done for this Sprint

- [ ] All Must Have tasks (S5-01 through S5-09) completed
- [ ] Campaign schedule has matches for all 5 chapters (Prologue through Return)
- [ ] All new opponents have profiles, dialogue, and i18n keys
- [ ] Murchadh rematch is a standard match (not scripted) in Chapter 4
- [ ] Audio system plays placeholder sounds for all board events
- [ ] Music changes per scene/chapter with crossfade
- [ ] Full campaign autoplay completes without crashes
- [ ] All tests pass (264+ tests, no regressions beyond pre-existing)
- [ ] Narrator text bridges every chapter transition
- [ ] Code follows ADR-0001 architecture
