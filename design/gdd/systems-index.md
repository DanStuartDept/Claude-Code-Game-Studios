# Systems Index: Fidchell

> **Status**: Approved
> **Created**: 2026-03-28
> **Last Updated**: 2026-03-28
> **Source Concept**: FIDCHELL_GAME_CONCEPT.md

---

## Overview

Fidchell is an asymmetric Celtic strategy board game (7x7 grid, custodial capture)
wrapped in a single-player campaign of disgrace, exile, and return. The mechanical
scope is focused: one board game with AI opponents, a 5-chapter campaign with 13
named characters, and systems for reputation, feuds, and reactive dialogue. No
crafting, no inventory, no open world — the complexity lives in the AI personalities,
the feud state machine, and the narrative layer that makes each match personal.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Board Rules Engine | Core | MVP | Designed | [design/gdd/board-rules-engine.md](board-rules-engine.md) | None |
| 2 | AI System | Core | MVP | Designed | [design/gdd/ai-system.md](ai-system.md) | Board Rules Engine |
| 3 | Campaign System | Gameplay | Vertical Slice | Designed | [design/gdd/campaign-system.md](campaign-system.md) | Board Rules Engine, AI System |
| 4 | Reputation System | Gameplay | Vertical Slice | Designed | [design/gdd/reputation-system.md](reputation-system.md) | Campaign System |
| 5 | Feud System | Gameplay | Alpha | Designed | [design/gdd/feud-system.md](feud-system.md) | Campaign System, Reputation System |
| 6 | Dialogue System | Narrative | Vertical Slice | Designed | [design/gdd/dialogue-system.md](dialogue-system.md) | Campaign System, Feud System |
| 7 | Save System | Persistence | Alpha | Designed | [design/gdd/save-system.md](save-system.md) | Campaign System, Reputation System, Feud System |
| 8 | Board UI | Presentation | MVP | Designed | [design/gdd/board-ui.md](board-ui.md) | Board Rules Engine, Scene Management |
| 9 | Campaign UI | Presentation | Alpha | Designed | [design/gdd/campaign-ui.md](campaign-ui.md) | Campaign System, Reputation System, Feud System |
| 10 | Audio System | Audio | Full Vision | Designed | [design/gdd/audio-system.md](audio-system.md) | Scene Management, Board Rules Engine |
| 11 | Tutorial System | Meta | Alpha | Designed | [design/gdd/tutorial-system.md](tutorial-system.md) | Board Rules Engine, Board UI, Dialogue System |
| 12 | Scene Management | Meta | MVP | Designed | [design/gdd/scene-management.md](scene-management.md) | None |

---

## Categories

| Category | Description |
|----------|-------------|
| **Core** | The board game rules and AI that plays it |
| **Gameplay** | Campaign progression, reputation, and feuds |
| **Narrative** | Dialogue and narrator voice |
| **Persistence** | Save/load for campaign state |
| **Presentation** | Board rendering, campaign map, touch input |
| **Audio** | Music, SFX, ambient |
| **Meta** | Tutorial, scene transitions, menus, settings |

---

## Priority Tiers

| Tier | Systems | Target Milestone | What It Proves |
|------|---------|------------------|----------------|
| **MVP** | Board Rules Engine, AI System, Board UI, Scene Management | First playable | "Is Fidchell fun on a phone?" |
| **Vertical Slice** | Campaign System, Reputation System, Dialogue System | Vertical slice | "Does the campaign loop work?" (Prologue + Chapter 1) |
| **Alpha** | Feud System, Save System, Campaign UI, Tutorial System | Alpha | Full campaign playable, persistent, accessible |
| **Full Vision** | Audio System | Beta / Release | Celtic tone and atmosphere |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **Board Rules Engine** — the rules of the game; everything builds on this
2. **Scene Management** — app skeleton: screen transitions, menus, settings

### Core Layer (depends on foundation)

3. **AI System** — depends on: Board Rules Engine (needs legal moves and board state)
4. **Board UI** — depends on: Board Rules Engine, Scene Management (renders board, handles touch)

### Feature Layer (depends on core)

5. **Campaign System** — depends on: Board Rules Engine, AI System (runs matches against AI opponents)
6. **Reputation System** — depends on: Campaign System (earns rep from match results)
7. **Feud System** — depends on: Campaign System, Reputation System (injects rematches, grants bonus rep)
8. **Dialogue System** — depends on: Campaign System, Feud System (text varies by opponent data and rivalry state)
9. **Save System** — depends on: Campaign System, Reputation System, Feud System (persists all their state)

### Presentation Layer (depends on features)

10. **Campaign UI** — depends on: Campaign System, Reputation System, Feud System (displays campaign state)

### Polish Layer (depends on everything)

11. **Tutorial System** — depends on: Board Rules Engine, Board UI, Dialogue System (guided first match)
12. **Audio System** — depends on: Scene Management, Board Rules Engine (music per scene, SFX on events)

---

## Recommended Design Order

| Order | System | Priority | Layer | Est. Effort |
|-------|--------|----------|-------|-------------|
| 1 | Board Rules Engine | MVP | Foundation | M |
| 2 | AI System | MVP | Core | L |
| 3 | Scene Management | MVP | Foundation | S |
| 4 | Board UI | MVP | Core | M |
| 5 | Campaign System | Vertical Slice | Feature | M |
| 6 | Reputation System | Vertical Slice | Feature | S |
| 7 | Dialogue System | Vertical Slice | Feature | M |
| 8 | Feud System | Alpha | Feature | M |
| 9 | Save System | Alpha | Feature | S |
| 10 | Campaign UI | Alpha | Presentation | M |
| 11 | Tutorial System | Alpha | Polish | M |
| 12 | Audio System | Full Vision | Polish | S |

Effort: S = 1 session, M = 2-3 sessions, L = 4+ sessions.

---

## Circular Dependencies

None found.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| AI System | Technical | 7 difficulty levels plus distinct play styles (defensive, aggressive, tactical, erratic) is a significant AI challenge for an asymmetric board game | Prototype early; start with basic minimax, layer personality on top |
| Feud System | Design | State machine that injects content into campaign flow and affects dialogue — touches many systems | Design the state machine formally; keep feud triggers simple initially |
| Board UI | Technical | Touch input for a strategy board game on mobile — piece selection, legal move display, drag vs tap — must feel precise on small screens | Prototype touch controls early on real devices |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 12 |
| Design docs started | 12 |
| Design docs reviewed | 0 |
| Design docs approved | 0 |
| MVP systems designed | 4/4 |
| Vertical Slice systems designed | 3/3 |

---

## Next Steps

- [ ] Design MVP-tier systems first (use `/design-system [system-name]`)
- [ ] Run `/design-review` on each completed GDD
- [ ] Prototype Board Rules Engine + AI early (highest risk)
- [ ] Prototype touch controls on a real mobile device
- [ ] Run `/gate-check pre-production` when MVP systems are designed
