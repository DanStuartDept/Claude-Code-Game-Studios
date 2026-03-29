# Balance Analysis — Sprint 6

**Date**: 2026-03-29
**Runs**: 3 full autoplay campaigns with scaled player AI
**Method**: `autoplay.cfg` fast mode via Godot MCP, AI-vs-AI with player difficulty scaling by chapter

## Campaign Summary (3 runs)

| Metric | Run 1 | Run 2 | Run 3 | Average |
|--------|-------|-------|-------|---------|
| Total matches | 35 | 57 | 37 | 43.0 |
| Wins (required: 16) | 16 | 16 | 16 | 16.0 |
| Losses | 19 | 41 | 21 | 27.0 |
| Win rate | 46% | 28% | 43% | 39% |
| Total moves | 830 | 1268 | 817 | 971.7 |
| Avg moves/match | 23 | 22 | 22 | 22.3 |
| Final reputation | 114 | 116 | 110 | 113.3 |
| Fastest win (moves) | 0* | 0* | 0* | — |
| Slowest win (moves) | 66 | 86 | 52 | 68.0 |

*\*Tutorial auto-skip counts as 0-move win*

## Player AI Configuration

| Chapter | Player Difficulty | Mistake Chance | Personality |
|---------|-------------------|----------------|-------------|
| 0 (Prologue) | 1 | 20% | Balanced |
| 1 (The West) | 2 | 17% | Balanced |
| 2 (Old Roads) | 3 | 14% | Balanced |
| 3 (Midlands) | 4 | 11% | Balanced |
| 4 (Return) | 5 | 8% | Balanced |

## Per-Opponent Analysis (aggregated across 3 runs)

| Opponent | Ch | Diff | Wins | Losses | Win Rate | Avg Win Moves | Avg Loss Moves | Total Attempts |
|----------|---:|-----:|-----:|-------:|---------:|--------------:|---------------:|---------------:|
| *(scripted)* | 0 | — | 0 | 4* | 0% | — | 19.2 | 4 |
| murchadh (tutorial+final) | 0,4 | 7 | 8 | 0 | 100% | 9.8 | — | 8 |
| seanan | 1 | 1 | 4 | 2 | 67% | 27.5 | 22.0 | 6 |
| brigid | 1 | 2 | 4 | 4 | 50% | 24.0 | 10.0 | 8 |
| tadhg | 1 | 2 | 3 | 0 | 100% | 27.3 | — | 3 |
| fiachra (ch1 boss) | 1 | 3 | 3 | 7 | 30% | 32.0 | 17.7 | 10 |
| **orlaith** | **2** | **4** | **3** | **42** | **6.7%** | **50.7** | **15.7** | **45** |
| diarmait | 2 | 3 | 3 | 9 | 25% | 36.0 | 15.1 | 12 |
| caoimhe | 2 | 5 | 6 | 2 | 75% | 36.0 | 35.5 | 8 |
| conchobar (ch2 boss) | 2 | 5 | 6 | 1 | 86% | 31.7 | 27.0 | 7 |
| eithne | 3 | 5 | 3 | 2 | 60% | 43.3 | 39.5 | 5 |
| **ruairi** | **3** | **4** | **3** | **9** | **25%** | **23.3** | **15.3** | **12** |
| conchobar (ch3 rematch) | 3 | 5 | — | — | — | — | — | *(included above)* |
| niall (ch3 boss) | 3 | 6 | 3 | 0 | 100% | 42.7 | — | 3 |
| caoimhe (ch4 rematch) | 4 | 5 | — | — | — | — | — | *(included above)* |
| saoirse | 4 | 6 | 3 | 1 | 75% | 34.7 | 37.0 | 4 |

*\*Scripted loss is intentional (narrative)*

## Key Findings

### 1. Orlaith is a Massive Difficulty Spike (CRITICAL)

Orlaith (ch2, difficulty 4) has a **6.7% win rate** across 45 attempts. She took 5, 24, and 15 attempts to beat across the 3 runs. This is the single biggest balance problem:

- She's the **first opponent in ch2**, immediately after the player AI scales from difficulty 2 → 3
- At difficulty 4, she's harder than the ch1 boss (fiachra, diff 3) by a full tier
- Her avg loss is only 15.7 moves (quick losses) vs avg win of 50.7 moves (grindy wins)
- She creates a "wall" that extends ch2 by 15-20+ extra matches

**Recommendation**: Reduce orlaith's difficulty from 4 → 3. She's the chapter opener, not the boss.

### 2. Difficulty Curve is Non-Monotonic

The intended difficulty curve within chapters doesn't hold:

**Ch2 intended order**: orlaith(4) → diarmait(3) → caoimhe(5) → conchobar(5, boss)
**Actual difficulty**: orlaith(6.7% WR) → diarmait(25% WR) → caoimhe(75% WR) → conchobar(86% WR)

The boss (conchobar, diff 5) is **easier** than the first two standard opponents. This is because:
- By the time the player beats orlaith/diarmait, their AI level (ch2 = difficulty 3) has had many practice reps
- The AI's Balanced personality may interact differently with different opponent personalities

**Recommendation**: Reorder ch2: diarmait(3) → orlaith(3, reduced) → caoimhe(4, reduced) → conchobar(5, boss). Or reduce orlaith and keep the order.

### 3. Fiachra (Ch1 Boss) is Appropriately Hard

Fiachra has a 30% win rate at difficulty 3. As a ch1 boss against player difficulty 2, this creates a moderate challenge (avg 3.3 attempts). This feels right for a first boss encounter.

### 4. Ruairi is a Secondary Wall

Ruairi (ch3, difficulty 4) has a 25% win rate. Similar to orlaith but less extreme. As the second opponent in ch3 (player difficulty 4 vs opponent difficulty 4), this is an even match that skews toward the opponent due to the attacker advantage in Hnefatafl.

**Recommendation**: Reduce ruairi from 4 → 3, or swap order with eithne so the player faces the easier opponent first.

### 5. Late-Game Opponents Are Too Easy

| Opponent | Difficulty | Win Rate | Note |
|----------|-----------|----------|------|
| niall (ch3 boss) | 6 | 100% | Never lost in 3 runs |
| saoirse (ch4) | 6 | 75% | Only 1 loss in 4 attempts |
| murchadh (final) | 7 | 100% | Never lost in 8 attempts |

The final boss (murchadh, diff 7) has a **100% first-attempt win rate**. By ch4, the player AI (diff 5, 8% mistakes) dominates even difficulty 7 opponents.

**Recommendation**: Increase murchadh to difficulty 8 or 9. Increase niall to 7. The final boss should require at least 2-3 attempts on average.

### 6. Match Length Distribution

- Average across all matches: **22 moves** (in the 15-40 sweet spot)
- Losses tend to be short (10-20 moves) — the king gets captured quickly
- Wins tend to be longer (25-50 moves) — king escape requires patient play
- Some extreme outliers: 86-move win, 73-move loss
- The 10-move loss pattern (appears frequently for orlaith/ruairi) suggests the opponent captures the king very efficiently at those difficulty levels

### 7. Reputation Accumulation

- Average final reputation: **113** (above the ch4 threshold of 60)
- Rep gates at ch2(15), ch3(35), ch4(60) are never blocking — players always have enough rep by the time they complete a chapter
- Rep breakdown: base(80) dominates, with speed(8), rematch(8), boss(12), decisive(5) as bonuses
- The base reputation alone (80 for 16 wins × 5 base) exceeds all thresholds

**Recommendation**: Rep thresholds are fine. Could increase ch4 threshold to 80+ if you want gating to ever matter.

### 8. Attacker vs Defender Asymmetry

Every loss shows `winner: attacker (king_captured)` and every win shows `winner: defender (king_escaped)`. The player always plays as defender. The attacker advantage in Hnefatafl is significant — at equal skill levels, the attacker wins more often. This is why same-difficulty matchups (e.g., player diff 4 vs opponent diff 4) show <50% win rates.

## Tuning Recommendations (Priority Order)

### Must Fix
1. **Reduce orlaith difficulty**: 4 → 3 (eliminates the ch2 wall)
2. **Increase murchadh difficulty**: 7 → 9 (final boss should be a real challenge)

### Should Fix
3. **Reduce ruairi difficulty**: 4 → 3 (smooths ch3 entry)
4. **Increase niall difficulty**: 6 → 7 (ch3 boss should be harder than ch3 opponents)
5. **Reorder ch2**: diarmait(3) first, then orlaith(3), caoimhe(5), conchobar(5)

### Consider
6. **Increase ch4 rep threshold**: 60 → 80 (make gating meaningful)
7. **Increase saoirse difficulty**: 6 → 7 (ch4 should feel dangerous)
8. **Add mistake_chance to opponent profiles** for fine-grained tuning beyond difficulty level

## Raw Data Location

- `production/balance-data/run1_summary.json` / `run1_log.jsonl`
- `production/balance-data/run2_summary.json` / `run2_log.jsonl`
- `production/balance-data/run3_summary.json` / `run3_log.jsonl`
