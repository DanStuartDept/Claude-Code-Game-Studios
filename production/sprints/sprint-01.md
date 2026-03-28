# Sprint 1 — MVP Foundation

> **Status**: Active
> **Goal**: Play one complete Fidchell match against AI on screen
> **Milestone**: First Playable (MVP tier)
> **Created**: 2026-03-28

## Sprint Goal

Build the four MVP-tier systems (Board Rules Engine, Scene Management, AI
System, Board UI) to production quality and integrate them into a playable
match: the player taps pieces on a 7x7 board, the AI responds, captures
resolve visually, and the match ends with a win/loss screen. No campaign,
no menus beyond a "Play" button — just the core loop.

## What This Sprint Proves

"Is Fidchell fun on a phone?" — the fundamental question from the systems
index MVP tier. If the answer is yes, everything else (campaign, reputation,
feuds) is layering on a solid foundation. If the answer is no, we learn that
before investing in 8 more systems.

## Capacity

This is a solo project with no fixed timeline. Sprint "duration" is measured in
sessions, not calendar days. The scope is designed to be completable in ~10-14
focused sessions.

- Estimated sessions: 12
- Buffer (20%): ~2 sessions reserved for debugging, iteration, and surprises
- Available: ~10 sessions of planned work

## Tasks

### Must Have (Critical Path)

| ID | Task | System | Est. Sessions | Dependencies | Acceptance Criteria |
|----|------|--------|---------------|--------------|---------------------|
| S1-01 | **Production Board Rules Engine** — Rewrite from prototype to Autoload singleton with signals, match modes, typed API per ADR-0001 | Board Rules Engine | 1 | Prototype (done) | All 19 acceptance criteria from GDD pass; all signals emit correctly; GdUnit4 tests |
| S1-02 | **Board Rules Resources** — Create `BoardLayout` custom Resource class for starting positions and tuning knobs | Board Rules Engine | 0.5 | S1-01 | Layout loads from `.tres`; no hardcoded values in engine |
| S1-03 | **Scene Manager** — Implement SceneManager Autoload: scene registry, base scene swap, overlay stack, fade transitions | Scene Management | 1.5 | None | Base scenes swap with fade; overlays push/pop; input blocked during transitions; signals fire |
| S1-04 | **Core AI — Minimax + Alpha-Beta** — Implement core evaluator: board position scoring, minimax search with alpha-beta pruning, configurable depth | AI System | 2 | S1-01 | AI returns valid move every turn; depth 1-4 search works; evaluation completes < 200ms on desktop |
| S1-05 | **AI Personality Layer** — Implement personality reweighting (defensive, aggressive, tactical, erratic) and difficulty-based mistake injection | AI System | 1.5 | S1-04 | 4 personality types produce visibly different play; difficulty 1 is beatable in 2-3 tries |
| S1-06 | **AI Resources** — Create `AIPersonality` and `OpponentProfile` custom Resource classes; configure at least 1 opponent (Seanán, difficulty 1) | AI System | 0.5 | S1-05 | Profile loads from `.tres`; AI uses loaded personality weights |
| S1-07 | **Board UI — Board rendering** — Render 7x7 grid with pieces, tile types (throne, corners), and responsive scaling for phone/tablet | Board UI | 1.5 | S1-01, S1-03 | Board renders correctly on 4.7" to 10"+ screens; pieces distinguishable |
| S1-08 | **Board UI — Input & Animation** — Tap-to-select, tap-to-move, legal move highlights, piece slide animation, capture animation | Board UI | 2 | S1-07 | Tap selects piece and shows legal moves; tap destination submits move; pieces animate; captures animate sequentially |
| S1-09 | **Match Integration** — Wire all systems together: SceneManager loads match scene, BoardUI talks to BoardRules via signals, AI takes turns, match ends with result overlay | Integration | 1 | S1-01 through S1-08 | Player can play a full match against AI opponent; win/loss detected and displayed |

### Should Have

| ID | Task | System | Est. Sessions | Dependencies | Acceptance Criteria |
|----|------|--------|---------------|--------------|---------------------|
| S1-10 | **Minimal main menu** — Title screen with a "Play" button that launches a match via SceneManager | Scene Management | 0.5 | S1-03 | App opens to menu; tapping Play starts a match |
| S1-11 | **Turn indicator & last move** — HUD showing whose turn it is, last move highlight on board | Board UI | 0.5 | S1-08 | Active side displayed; previous move visually indicated |
| S1-12 | **AI think indicator** — Show "thinking..." during AI turn with configurable delay | Board UI / AI | 0.5 | S1-08, S1-04 | Visible feedback during AI turn; think time feels natural |
| S1-13 | **King threat visual** — Pulse/glow on King when 2+ attackers are adjacent | Board UI | 0.5 | S1-08 | King visually reacts to `king_threatened` signal |

### Nice to Have

| ID | Task | System | Est. Sessions | Dependencies | Acceptance Criteria |
|----|------|--------|---------------|--------------|---------------------|
| S1-14 | **Drag-to-move** — Alternative input: drag piece to destination with snap/cancel | Board UI | 1 | S1-08 | Piece follows finger; snaps to valid cell; cancels on invalid release |
| S1-15 | **Capture preview** — Highlight which enemy piece(s) will be captured before confirming move | Board UI | 0.5 | S1-08 | Threatened enemies highlighted on legal move hover |
| S1-16 | **Second opponent** — Configure Brigid (difficulty 2, defensive personality) for variety | AI System | 0.5 | S1-06 | Second opponent plays distinctly from first |

## Carryover from Previous Sprint

None — first sprint.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| AI minimax too slow on mobile at depth 3-4 | Medium | High | Implement iterative deepening; test on real device early (S1-04); fall back to depth 2 if needed |
| Touch targets too small on 4.7" phone | Medium | High | Design for 44pt minimum from start (S1-07); test on smallest target device |
| Godot 4.6 API gaps vs training data | Low | Medium | Use Context7 MCP + engine-reference docs; prototype validated Godot runs correctly |
| Board UI performance with animations | Low | Medium | Profile early; Fidchell is 25 pieces max on a 7x7 grid — well within budget |

## Dependencies on External Factors

- **Real mobile device** needed for touch and performance testing (S1-07, S1-08). Desktop testing is sufficient for logic, but touch feel requires a phone.
- **Art assets** — Sprint 1 uses placeholder art (colored shapes for pieces, simple grid). No artist dependency.

## Implementation Order

The dependency chain dictates the build order:

```
Session 1-2:   S1-01 + S1-02 (Board Rules Engine — production)
               S1-03 (Scene Manager — parallel, no dependency)
Session 3-4:   S1-04 (Core AI — needs Board Rules)
Session 5-6:   S1-05 + S1-06 (AI Personality — needs Core AI)
               S1-07 (Board UI rendering — needs Board Rules + Scene Manager)
Session 7-8:   S1-08 (Board UI input/animation — needs Board UI rendering)
Session 9:     S1-09 (Integration — needs everything)
Session 10:    S1-10 through S1-13 (Should Haves — polish the loop)
Buffer:        Debugging, iteration, surprises
```

## Definition of Done for this Sprint

- [ ] All Must Have tasks (S1-01 through S1-09) completed
- [ ] A complete match can be played from start to finish on screen
- [ ] AI opponent makes valid, non-trivial moves
- [ ] Win/loss is correctly detected and displayed
- [ ] All GdUnit4 tests passing for Board Rules and AI evaluation
- [ ] No crashes during normal match flow
- [ ] Code follows ADR-0001 architecture (Autoloads, signals, Resources)
- [ ] Design documents updated for any deviations discovered during implementation
