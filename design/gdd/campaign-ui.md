# Campaign UI

> **Status**: Designed
> **Author**: user + game-designer
> **Last Updated**: 2026-03-28
> **Implements Pillar**: Presentation — the player's window into their journey

## Overview

Campaign UI is the campaign map screen — the player's hub between matches. It displays the current chapter location, the sequence of opponents ahead, the player's reputation score with progress toward the next chapter threshold, and any active feud indicators. It is loaded as the `campaign_map` base scene by Scene Management. The player interacts with it by tapping the next available match to begin, or reviewing completed matches and their results. It reads all data from the Campaign System, Reputation System, and Feud System but owns no game logic — it is purely a display and navigation layer. On mobile, it must communicate the journey's progress at a glance: where the player is, what's ahead, and how close they are to moving on.

## Player Fantasy

The campaign map should feel like a road. Not a menu of levels — a journey with weight and direction. The player should see the west coast behind them and Tara ahead. Each opponent should be a face, not a button. Completed matches should feel like milestones passed. The reputation bar should feel like a tide rising. Feud icons should feel like unfinished business — a face marked with hostility, waiting ahead. The map should tell the story of the campaign without words: how far the player has come, who they've beaten, who's still in the way, and how close they are to the final confrontation. Opening the campaign map after a hard win should feel like looking at a road that's gotten shorter.

## Detailed Design

### Core Rules

#### 1. Screen Layout

The campaign map is a single scrollable screen in portrait orientation:

| Region | Position | Content |
|--------|----------|---------|
| **Chapter header** | Top | Chapter name, location name, illustrated chapter banner |
| **Reputation display** | Below header | Current reputation score, progress bar toward next chapter threshold, tier label (Unknown/Emerging/Respected/Feared/Legendary) |
| **Match list** | Centre (scrollable) | Vertical list of opponent cards for the current chapter — portrait, name, status (upcoming/active/completed/feud) |
| **Navigation** | Bottom | Back arrow to main menu, chapter navigation dots (completed chapters are tappable for review) |

The layout scrolls vertically if the match list exceeds the visible area. The reputation display and chapter header remain fixed at the top.

#### 2. Opponent Cards

Each match in the chapter is represented by an opponent card:

| Card State | Visual Treatment | Tap Behavior |
|------------|-----------------|-------------|
| **Upcoming** | Portrait dimmed, name visible, "?" or silhouette if first encounter | Not tappable — locked until previous match is completed |
| **Active (next match)** | Portrait full colour, name and title visible, subtle glow or pulse | Tappable — initiates pre-match dialogue then match |
| **Completed (won)** | Portrait full colour with win indicator (checkmark or laurel), move count shown | Tappable — shows match summary (result, moves, reputation earned). Option to replay for practice. |
| **Completed (lost then won)** | Same as won, but with a small indicator showing retries | Tappable — shows match summary |
| **Feud rematch** | Portrait with feud icon overlay (crossed swords or flame), hostile border colour | Tappable if active — initiates feud rematch sequence |
| **Nemesis** | Portrait with nemesis icon (skull or dark flame), distinct border | Tappable if active — initiates nemesis rematch |
| **Feud resolved** | Portrait with resolved indicator (handshake or faded feud icon) | Tappable — shows match summary |

#### 3. Reputation Display

| Element | Content |
|---------|---------|
| **Score** | Current reputation as a number (e.g., "22") |
| **Progress bar** | Visual bar from current threshold to next threshold (e.g., 15→35 for Chapter 2→3) |
| **Tier label** | Current reputation tier name (e.g., "Emerging") |
| **Next threshold** | Text: "Next chapter: 35" or "Final boss: 80" |

After the final boss threshold is met, the progress bar fills completely and the label changes to the player's tier name.

#### 4. Chapter Navigation

- **Current chapter** is always displayed by default
- **Completed chapters** are accessible via navigation dots at the bottom — tapping a dot shows that chapter's match list in completed state (all cards show results)
- **Future chapters** are shown as locked dots with the reputation threshold displayed
- **Chapter transitions** use the same fade transition as Scene Management (0.4s)

#### 5. Initiating a Match

When the player taps the active opponent card:

1. Campaign UI calls Campaign System to begin match sequence
2. Campaign System triggers pre-match dialogue via Dialogue System
3. Scene Management pushes dialogue overlay on top of campaign map
4. After dialogue, Scene Management transitions to match scene
5. After match + post-match dialogue + result, Scene Management returns to campaign map
6. Campaign UI refreshes to reflect updated state (new active match, reputation change, feud updates)

#### 6. Feud Indicators

When an opponent has a non-neutral feud state, their card displays it:

| Feud State | Card Indicator |
|------------|---------------|
| Feud Pending | No indicator on card (feud hasn't fired yet — player shouldn't know it's coming) |
| In Feud | Feud icon overlay on portrait, hostile border colour, card may appear in a future chapter's flex slot |
| Nemesis | Nemesis icon overlay, distinct dark border |
| Feud Resolved | Faded feud icon or handshake indicator — tension cleared |

Feud Pending is intentionally invisible to the player. The surprise of a rival reappearing is part of the narrative.

#### 7. Responsive Layout

| Screen Size | Adaptation |
|------------|------------|
| **Small phone (< 5.5")** | Opponent cards compact — smaller portraits, single-line name. Reputation bar full width. |
| **Large phone (5.5"–6.7")** | Standard layout — comfortable portraits, two-line name + title. |
| **Tablet (7"+)** | Cards do not stretch to fill — max width capped. Extra margins. Chapter banner may show more illustrated detail. |

Minimum tap target: 44pt per card (Apple HIG). Cards are full-width rows, so this is easily met.

#### 8. Campaign Complete State

When `campaign_complete` is true:

- All chapters are accessible for review
- All opponent cards show completed state
- Reputation display shows final score and tier
- A "Journey Complete" banner or indicator at the top
- No active match — tapping any completed match shows its summary with replay option

### States and Transitions

| State | Entry Condition | Behavior | Exit Condition |
|-------|----------------|----------|----------------|
| **Loading** | Scene Management loads `campaign_map` scene | Read campaign state, reputation, feud data. Build match list for current chapter. | Data loaded, UI rendered |
| **Browsing** | UI rendered, player viewing campaign map | Display current chapter, match list, reputation. Accept taps on active match or chapter dots. Scroll match list. | Player taps active match, chapter dot, or back button |
| **Match Initiated** | Player taps active opponent card | Notify Campaign System. Campaign triggers dialogue overlay. Campaign map remains loaded underneath. | Match sequence completes, returns to campaign map |
| **Chapter Review** | Player taps a completed chapter dot | Display that chapter's match list in completed state. All cards show results. | Player taps current chapter dot or back |
| **Refreshing** | Returned from match sequence | Re-read campaign state, reputation, feud data. Update match list, reputation display, feud indicators. Animate any changes (new reputation, new active match). | Refresh complete, return to Browsing |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Campaign System** | Campaign UI reads state | `Campaign.get_current_chapter()`, `Campaign.get_match_list(chapter)`, `Campaign.get_match_history()`, `Campaign.get_unlocked_opponents()`, `Campaign.is_campaign_complete()`. Campaign UI calls `Campaign.initiate_match(match_slot_id)` when player taps active match. |
| **Reputation System** | Campaign UI reads reputation | `Reputation.get_reputation()`, `Reputation.get_reputation_tier()`, `Reputation.get_next_threshold()` for display. |
| **Feud System** | Campaign UI reads feud state | `Feud.get_feud_state(opponent_id)` for each opponent card's feud indicator. |
| **Scene Management** | Scene Management loads Campaign UI | Campaign UI is the `campaign_map` base scene. Dialogue and match result overlays are pushed on top. |
| **Save System** | No direct interaction | Campaign UI does not trigger saves — Campaign System handles auto-save after match results. |

## Formulas

No mathematical formulas. Campaign UI performs no calculations — it reads computed values from other systems. The Reputation System owns the score and tier lookup. The Campaign System owns gating logic. Campaign UI displays results only.

The only layout calculation is inherited from the responsive scaling pattern established in Board UI:

```
card_height = max(portrait_size + padding, min_tap_target)
visible_cards = (screen_height - header_height - nav_height) / card_height
```

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|-------------------|-----------|
| Chapter has more matches than fit on screen (Chapter 3 has 5 + possible feud) | Match list scrolls vertically. Header and reputation display remain fixed. | Standard mobile scroll pattern |
| Player returns from match and reputation crossed a tier boundary | Reputation tier label updates with a brief highlight animation. Progress bar animates to new position. | Tier changes should feel like a milestone |
| Player returns from match and a feud was triggered | No visible change — Feud Pending is hidden from the player. The feud icon appears only when the rematch slot activates in a later chapter. | Surprise is part of the narrative design |
| Player taps an upcoming (locked) opponent card | No response. Card appears dimmed/locked. Optional: subtle shake animation to indicate "not yet." | Clear affordance — only the active card responds |
| Player taps a completed match card | Shows match summary popup: opponent name, result, move count, reputation earned, feud outcome. Option to replay for practice. | Reviewing history reinforces the journey |
| Campaign complete — all chapters reviewable | All chapter dots are tappable. All cards show completed state. No active match indicator. | The map becomes a trophy case |
| Feud rematch injected into current chapter | Match list updates to include the feud card at the flex slot position. Card appears with feud visual treatment. | Feud rematches appear naturally in the match sequence |
| Player has < threshold reputation but boss is defeated | Next chapter dot shows locked with threshold number. Reputation display highlights the gap. | Player knows exactly what they need |
| Screen rotation attempted | Ignored — portrait orientation locked (consistent with Board UI). | Simplifies layout, matches Board UI decision |
| Very long opponent name or title | Text truncates with ellipsis. Full name visible in match summary popup. | Mobile screen width is limited |

## Dependencies

| System | Direction | Nature | Interface |
|--------|-----------|--------|-----------|
| **Campaign System** | This depends on | Hard — Campaign provides all match and chapter data | `get_current_chapter()`, `get_match_list()`, `get_match_history()`, `initiate_match()` |
| **Reputation System** | This depends on | Hard — Reputation provides score, tier, and threshold data | `get_reputation()`, `get_reputation_tier()`, `get_next_threshold()` |
| **Feud System** | This depends on | Hard — Feud provides per-opponent feud state for indicators | `get_feud_state(opponent_id)` |
| **Scene Management** | This depends on | Hard — Campaign UI is loaded as the `campaign_map` base scene | `change_scene()`, overlay stack |

**This system depends on:** Campaign System (hard), Reputation System (hard), Feud System (hard), Scene Management (hard).

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|--------------------|--------------------|
| `card_portrait_size` | 64pt | 48–96pt | Larger portraits — more recognizable faces, fewer cards visible | Smaller portraits — more cards visible, less visual impact |
| `reputation_bar_height` | 8pt | 4–16pt | More prominent progress bar | More subtle progress bar |
| `chapter_banner_height` | 120pt | 80–180pt | More illustrated atmosphere, less space for match list | More functional, less atmospheric |
| `card_spacing` | 8pt | 4–16pt | More breathing room between cards | Denser match list |
| `refresh_animation_duration` | 0.3s | 0.1–0.6s | Slower reputation/status updates — more dramatic | Snappier updates — more responsive |
| `scroll_momentum` | standard | low/standard/high | Faster scrolling through long match lists | More controlled scrolling |

## Acceptance Criteria

- [ ] Campaign map displays current chapter name, location, and illustrated banner
- [ ] Match list shows all opponents for current chapter with correct card states
- [ ] Active match card is visually distinct (glow/pulse) and tappable
- [ ] Upcoming match cards are dimmed and not tappable
- [ ] Completed match cards show win indicator and are tappable for summary
- [ ] Reputation score, progress bar, tier label, and next threshold all display correctly
- [ ] Progress bar animates when reputation changes
- [ ] Feud indicators appear on opponent cards for In Feud and Nemesis states
- [ ] Feud Pending state is NOT visible to the player
- [ ] Feud Resolved shows resolved indicator on card
- [ ] Chapter navigation dots allow reviewing completed chapters
- [ ] Future chapter dots show locked state with reputation threshold
- [ ] Tapping active match initiates Campaign System match sequence
- [ ] Campaign map refreshes correctly after returning from a match
- [ ] Campaign complete state shows all chapters reviewable with "Journey Complete" indicator
- [ ] Layout adapts to small phone, large phone, and tablet screen sizes
- [ ] All tap targets meet 44pt minimum (Apple HIG)
- [ ] Portrait orientation locked
- [ ] Art style consistent with hand-drawn LucasArts adventure game direction
- [ ] Match list scrolls vertically with fixed header when content exceeds screen
- [ ] All display data read from systems — no hardcoded values

## Open Questions

| Question | Owner | Target Resolution | Resolution |
|----------|-------|-------------------|-----------|
| Should the campaign map show a literal illustrated map of Ireland with the journey path, or a more abstract chapter-based list? Map is atmospheric but harder to scale on small screens. | Art Director | Visual design phase | — |
| Should completed match summaries show a "Replay" button inline, or require navigating to Quick Play? | UX Designer | Playtesting | — |
| Should reputation changes animate with a "+5" floating number, or just the bar moving? | UX Designer | Visual design phase | — |
| Should the chapter banner illustration change based on progress within the chapter (e.g., darker as the boss approaches)? | Art Director | Visual design phase | — |
| How should feud rematches be introduced — does the feud card appear with a narrator line, or does it just show up in the match list? | Game Designer | Dialogue content phase | — |
