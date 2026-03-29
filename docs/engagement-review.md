# Engagement Review — Sprint 6

**Date**: 2026-03-29
**Source**: 3 autoplay campaigns (pre-tuning), balance-analysis.md data
**Focus**: Match length, difficulty ramp, close games, boss distinctiveness

## Match Length Sweet Spot (Target: 15-40 moves)

**Average**: 22 moves/match — solidly in the sweet spot.

| Category | Avg Moves | Assessment |
|----------|-----------|------------|
| All matches | 22 | Good |
| Wins only | 33 | Good — wins feel earned |
| Losses only | 15 | Good — quick failures, low frustration |
| Ch1 matches | 18 | Slightly short but fine for early game |
| Ch2 matches | 21 | Good |
| Ch3 matches | 24 | Good |
| Ch4 matches | 46 | Long — late-game matches drag |

**Issue**: Ch4 average of 46 moves is above the sweet spot. The player AI at difficulty 5 plays very carefully, leading to slow positional games. This may feel tedious for real players too.

**Recommendation**: Monitor post-tuning ch4 lengths. If murchadh at diff 9 creates 60+ move slogs, consider capping match length or adding a "no progress" stalemate rule.

## Difficulty Ramp

Pre-tuning difficulty curve by opponent encounter order:

```
Ch0: tutorial(skip) → scripted_loss
Ch1: seanan(1) → brigid(2) → tadhg(2) → fiachra(3, boss)
Ch2: orlaith(4!) → diarmait(3) → caoimhe(5) → conchobar(5, boss)
Ch3: eithne(5) → ruairi(4!) → conchobar(5, rematch) → niall(6, boss)
Ch4: caoimhe(5, rematch) → saoirse(6) → murchadh(7, final)
```

**Problem**: Ch2 opens with the hardest non-boss opponent (orlaith, diff 4) before dropping to a diff 3 opponent. This creates a "wall then relief" pattern that feels punishing rather than progressive.

**Post-tuning**: Orlaith reduced to 3, ruairi reduced to 3, niall raised to 7, murchadh raised to 9. The curve should now be:

```
Ch2: orlaith(3) → diarmait(3) → caoimhe(5) → conchobar(5, boss)  — smooth ramp
Ch3: eithne(5) → ruairi(3) → conchobar(5, rematch) → niall(7, boss) — valley then climb
Ch4: caoimhe(5, rematch) → saoirse(6) → murchadh(9, final) — steady climb
```

**Remaining concern**: Ch3 still has a difficulty valley (eithne 5 → ruairi 3 → conchobar 5). Consider swapping ruairi and eithne order so the player faces the easier opponent first.

## Close Games

The data shows a stark win/loss asymmetry:
- **Losses**: typically 10-15 moves, king captured quickly. Not close games.
- **Wins**: typically 25-50 moves, king escapes after extended play. Feel earned.

There are very few "close losses" (30+ move losses). This is due to Hnefatafl's attacker advantage — when the attacker AI plays well, it captures the king efficiently. When it doesn't, the king escapes.

**Assessment**: The lack of close losses is actually fine for engagement. Quick losses mean low frustration on retries. Long wins feel like genuine accomplishments. The pattern creates a "try again quickly, celebrate when you succeed" loop that works well.

## Boss Distinctiveness

| Boss | Ch | Diff | Personality | Win Rate | Avg Moves | Feel |
|------|---:|-----:|-------------|----------|-----------|------|
| fiachra | 1 | 3 | tactical | 30% | 32 | Moderate gate — good first boss |
| conchobar | 2 | 5 | tactical | 86% | 31 | Too easy for a boss (pre-tuning) |
| niall | 3 | 7* | balanced | 100%** | 43 | Too easy (pre-tuning, now diff 7) |
| murchadh | 4 | 9* | balanced | 100%** | 10 | Far too easy (pre-tuning, now diff 9) |

*Post-tuning values. **Pre-tuning results.

**Problem**: All bosses except fiachra were trivially easy. Conchobar, niall, and murchadh had 86-100% win rates. Bosses should be meaningful gates (30-50% first-attempt win rate).

**Post-tuning prediction**: Murchadh at diff 9 should be significantly harder. Niall at diff 7 should provide a real challenge. Conchobar is unchanged (diff 5) and may still be too easy — consider raising to 6 if post-tuning runs confirm.

**Boss personality issue**: Three bosses (conchobar, niall, murchadh) all use "balanced" personality. This makes them feel similar. Consider giving each a distinct AI personality:
- Conchobar: defensive (patient elder archetype matches)
- Niall: tactical (nine losses taught him to adapt)
- Murchadh: aggressive or balanced (cold precision fits balanced)

## Reputation Pacing

Total reputation across 16 required wins averages 113, well above the ch4 gate of 60. Rep never gates progress — players always have enough rep when they complete a chapter.

The rep bonuses (speed, rematch, boss, decisive) add flavor but don't materially affect pacing since base rep (5 per win × 16 wins = 80) already exceeds all gates.

**Assessment**: Rep gates serve as a narrative pacing device, not a difficulty gate. This is fine for a story-driven campaign. If you want rep to matter mechanically, raise thresholds (ch3: 50, ch4: 90) so players need bonus rep to progress.

## Summary of Engagement Strengths

1. Match length in the sweet spot (22 avg)
2. Quick losses reduce retry frustration
3. Wins feel earned (longer matches with king escape)
4. Rep system provides satisfying numeric progression
5. Chapter structure gives clear progression milestones

## Action Items (Priority)

1. Run post-tuning verification campaign to confirm improvements
2. Monitor ch4 match lengths — may need stalemate rule if 60+ moves
3. Consider swapping ch3 ruairi/eithne order for smoother ramp
4. Consider raising conchobar to diff 6 if still too easy
5. Differentiate boss AI personalities for distinct boss feel
