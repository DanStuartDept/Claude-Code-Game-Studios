# Sprint 3 — Polish & Completeness

> **Status**: Pending
> **Goal**: Harden the vertical slice — save/load, test coverage, mobile readiness, feud system
> **Milestone**: Alpha
> **Created**: 2026-03-29

## Sprint Goal

Make the vertical slice production-ready: persist progress between sessions,
verify correctness with automated tests, lock portrait orientation for mobile,
and add the Feud System to give the campaign emotional depth before expanding
content in later sprints.

## What This Sprint Proves

"Can the player close the app and come back?" (Save System) and "Do the core
systems actually work correctly?" (test coverage). Sprint 2 proved the campaign
loop works. Sprint 3 proves it works *reliably* and *persistently*.

## Capacity

Solo project, session-based. Sprint 1: 16 tasks across ~10 sessions. Sprint 2:
16 tasks across ~8 sessions. Velocity increasing as codebase matures.

- Estimated sessions: 12
- Buffer (20%): ~2 sessions
- Available: ~10 sessions of planned work

## Tasks

### Must Have (Critical Path)

| ID | Task | System | Est. Sessions | Dependencies | Acceptance Criteria |
|----|------|--------|---------------|--------------|---------------------|
| S3-01 | **Portrait orientation lock** — Set display/window/handheld/orientation in project.godot, verify UI scales correctly | Mobile | 0.25 | — | Game runs portrait-only on all platforms; no landscape rotation |
| S3-02 | **Save System — core** — SaveSystem autoload: auto-save after match result + chapter transition, load on campaign start, JSON at user://fidchell_save.json | Save | 1.5 | — | Close app mid-campaign, reopen → exact same chapter/match/reputation/history |
| S3-03 | **Save System — new game confirmation** — "New Campaign" warns if save exists, offers to overwrite or cancel | Save / UI | 0.5 | S3-02 | Starting new campaign with existing save shows confirmation dialog |
| S3-04 | **Save System — backup + version** — Write backup before save, include save_version field, reject future-version saves gracefully | Save | 0.5 | S3-02 | Backup file created; corrupted save shows error, doesn't crash |
| S3-05 | **Resume campaign from menu** — Main menu shows "Continue Campaign" button when save exists (loads save + goes to campaign map) | Campaign / UI | 0.5 | S3-02 | Save exists → "Continue" button visible; loads correct state |
| S3-06 | **Test coverage — BoardRules** — Run existing tests, fix any failures, add missing coverage to reach 80% | Testing | 1 | — | GdUnit4 passes all BoardRules tests; coverage ≥ 80% of public API |
| S3-07 | **Test coverage — ReputationSystem** — Unit tests for award_match_win (all bonus paths), tier lookup, config loading, reset | Testing | 0.5 | — | All bonus combinations tested; tier boundaries verified; config loading tested |
| S3-08 | **Test coverage — CampaignSystem** — Unit tests for match progression, chapter advancement, result history, encounter counting, save/load round-trip | Testing | 1 | — | Full campaign flow tested: start → win → advance → chapter gate → save/load |
| S3-09 | **Test coverage — DialogueSystem** — Unit tests for tag matching, specificity scoring, wildcard handling, type coercion (bool/string) | Testing | 0.5 | — | Tag matching tested with all field types; specificity ordering verified; regression test for bool/string bug |
| S3-10 | **Update production stage** — Move from Pre-Production to Production; update stage.txt and any milestone docs | Production | 0.25 | — | stage.txt reads "Production"; milestone docs reflect vertical slice complete |

### Should Have

| ID | Task | System | Est. Sessions | Dependencies | Acceptance Criteria |
|----|------|--------|---------------|--------------|---------------------|
| S3-11 | **Feud System — core state machine** — FendSystem autoload: per-opponent state (Neutral→Feud Pending→In Feud→Resolved/Nemesis), feud triggers on loss, tendency roll | Feud | 1.5 | S3-08 (campaign tests) | Losing to opponent with feud_tendency > 0 can trigger Feud Pending; state transitions follow GDD exactly |
| S3-12 | **Feud System — campaign integration** — Inject feud rematches into flex slots, +1 AI difficulty during feud, feud_state in dialogue context | Feud / Campaign | 1 | S3-11 | Feud rematch appears in campaign schedule; AI difficulty increases; dialogue tags include feud state |
| S3-13 | **Feud System — opponent profiles** — Add feud_tendency values to all opponent .tres files per GDD specs | Feud / Data | 0.25 | S3-11 | All opponent profiles have feud_tendency matching GDD values |
| S3-14 | **Feud dialogue lines** — Pre/post dialogue for feud and nemesis states (all Ch1 opponents) | Feud / Dialogue | 0.5 | S3-12 | Every feud/nemesis encounter has distinct dialogue |

### Nice to Have

| ID | Task | System | Est. Sessions | Dependencies | Acceptance Criteria |
|----|------|--------|---------------|--------------|---------------------|
| S3-15 | **Settings screen** — Pause/settings overlay: text speed toggle, sound volume (placeholder), new game button | UI | 0.5 | S3-02 | Settings accessible from campaign map; changes persist in save |
| S3-16 | **Save System — feud state** — Serialize feud state alongside campaign + reputation | Save / Feud | 0.25 | S3-02, S3-11 | Feud state survives app close/reopen |
| S3-17 | **Test coverage — SaveSystem** — Round-trip tests: save → load → verify all fields, corrupt file handling, version migration | Testing | 0.5 | S3-02 | Save/load round-trip verified; corrupt JSON handled; backup tested |

## Carryover from Previous Sprint

None — Sprint 2 completed all tiers.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Existing Sprint 1 tests may fail against Sprint 2 code changes | Medium | Medium | Run tests first (S3-06); fix before adding new tests |
| Feud system touches Campaign, AI, Dialogue, Reputation — integration complexity | Medium | High | Implement core state machine first (S3-11), integration second (S3-12) |
| Save system edge cases (interrupted writes, full storage, permissions) | Low | High | Backup file strategy (S3-04); test corrupt file handling |
| Portrait lock may break existing UI layouts | Low | Medium | Test immediately after setting (S3-01); fix layout issues in same task |

## Dependencies on External Factors

- None for this sprint. All systems are internal.
- Art assets remain placeholder (colored shapes, text labels).
- No device testing required yet (desktop simulation sufficient for portrait).

## Implementation Order

```
Session 1:     S3-01 (Portrait lock — quick win)
               S3-10 (Update production stage — quick win)
               S3-06 (Run existing BoardRules tests, fix failures)
Session 2-3:   S3-02 (Save System core — foundation for resume)
Session 4:     S3-03 + S3-04 (Save confirmation + backup)
               S3-05 (Resume campaign button)
Session 5:     S3-07 + S3-09 (Reputation + Dialogue tests)
Session 6:     S3-08 (Campaign tests — most complex)
Session 7-8:   S3-11 (Feud core state machine)
Session 9:     S3-12 + S3-13 (Feud integration + profiles)
Session 10:    S3-14 (Feud dialogue)
Buffer:        S3-15, S3-16, S3-17
```

## Definition of Done for this Sprint

- [ ] All Must Have tasks (S3-01 through S3-10) completed
- [ ] Game runs in portrait orientation only
- [ ] Player can close and reopen app with progress preserved
- [ ] "Continue Campaign" appears on menu when save exists
- [ ] GdUnit4 tests pass for BoardRules, ReputationSystem, CampaignSystem, DialogueSystem
- [ ] Test coverage ≥ 80% of public API for core systems
- [ ] Production stage updated from Pre-Production
- [ ] No crashes during normal campaign flow or save/load
- [ ] Code follows ADR-0001 architecture
