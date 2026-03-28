# Save System

> **Status**: Designed
> **Author**: user + game-designer
> **Last Updated**: 2026-03-28
> **Implements Pillar**: Persistence — the player's progress survives between sessions

## Overview

The Save System persists campaign progress to local storage so the player can resume between sessions. It serializes data from three systems — Campaign System (chapter, match position, match history, unlocked opponents), Reputation System (score), and Feud System (per-opponent state, encounter loss counts, pending feuds) — into a single save file. It does not save mid-match state; interrupted matches restart from the beginning. The system supports one save slot (one active campaign) with auto-save after every match result and chapter transition. It uses Godot's FileAccess API to write JSON to the user's local data directory. The Save System is invisible infrastructure — the player never sees a save screen. They close the app, come back, and everything is where they left it.

## Player Fantasy

The player should never think about saving. They close the app after a hard-fought match, open it the next morning on the train, and they're exactly where they left off — same chapter, same opponent ahead, same reputation, same feuds simmering. The save system is the absence of anxiety. No "did I save?" No progress lost. No save slots to manage. It just works. The only time the player should be aware saving exists is when they choose to start a New Game and are asked to confirm they want to erase their journey.

## Detailed Design

### Core Rules

#### 1. Save Slot

One save slot. One active campaign. No manual save/load UI.

- Starting a New Game overwrites the existing save (with confirmation dialog)
- There is no "save slot selection" screen
- The save file path: `user://fidchell_save.json` (Godot's `user://` maps to platform-appropriate local storage)

#### 2. Save Data Structure

The save file contains a single JSON object with versioned sections:

```
{
  "save_version": 1,
  "timestamp": "2026-03-28T14:30:00Z",
  "campaign": {
    "current_chapter": 2,
    "current_match_index": 7,
    "match_history": [
      {
        "opponent_id": "seanán",
        "match_slot_id": 3,
        "result": "win",
        "move_count": 18,
        "lost_at_least_once": false
      }
    ],
    "unlocked_opponents": ["seanán", "brigid", "tadhg", "fiachra", "orlaith"],
    "prologue_complete": true,
    "campaign_complete": false
  },
  "reputation": {
    "score": 22
  },
  "feud": {
    "opponent_states": {
      "tadhg": {
        "state": "feud_pending",
        "encounter_loss_count": 1,
        "trigger_chapter": 1
      }
    }
  },
  "settings": {
    "text_display_mode": "instant",
    "tap_to_advance_delay": 0.2
  }
}
```

#### 3. Auto-Save Triggers

The system auto-saves at these moments:

| Trigger | When | What Changed |
|---------|------|-------------|
| **Match complete** | After post-match dialogue dismissed, before returning to campaign map | Match history, reputation, feud state |
| **Chapter transition** | After chapter narration, before new chapter loads | Current chapter, match index |
| **Settings changed** | After player changes a setting | Settings block only |
| **Campaign complete** | After final victory narration | campaign_complete flag |

No manual save button. No save-on-exit (auto-save points are frequent enough that at most one match of progress can be lost).

#### 4. Load Behavior

- **App launch → Continue**: Read save file, validate version, restore state to all systems
- **App launch → No save file**: Continue button is hidden/disabled on main menu
- **App launch → Corrupted save**: Warn player, offer to start New Game. Do not crash.

Load sequence:
1. Read `user://fidchell_save.json`
2. Validate `save_version` — if newer than supported, warn and refuse (future-proofing)
3. Call `Campaign.load_state(data.campaign)`
4. Call `Reputation.load_state(data.reputation)`
5. Call `Feud.load_feud_data(data.feud)`
6. Apply `data.settings` to Settings manager
7. Transition to Campaign Map at the correct chapter/match position

#### 5. Save File Format

- **Format**: JSON (human-readable, debuggable, easy to validate)
- **Encoding**: UTF-8
- **Location**: `user://fidchell_save.json` (platform-mapped by Godot)
  - iOS: `Documents/` (backed up by iCloud if enabled)
  - Android: `internal storage/Android/data/[package]/files/`
- **Backup**: Before each write, copy current save to `user://fidchell_save.backup.json`. If the write fails, the backup survives.

#### 6. Save Versioning

The `save_version` field enables migration between game updates:

- Current version: `1`
- On load, if `save_version < current_version`, run migration functions in order (v1→v2, v2→v3, etc.)
- If `save_version > current_version` (downgrade), refuse to load — warn player
- Migration functions add new fields with defaults; they never remove data

#### 7. New Game

When the player selects New Game:

1. If a save file exists, show confirmation: "Starting a new game will erase your current journey. Are you sure?"
2. On confirm: delete save file, reset all systems to initial state, begin Prologue
3. On cancel: return to main menu

#### 8. No Mid-Match Saving

Matches are short (5–15 minutes). The Campaign System specifies that interrupted matches restart from the beginning. The Save System does not serialize board state, piece positions, or turn history. This keeps the save format simple and avoids desync bugs.

### States and Transitions

| State | Entry Condition | Behavior | Exit Condition |
|-------|----------------|----------|----------------|
| **No Save** | First app launch, or after New Game clears save | Continue button disabled. Only New Game available. | New Game started and first auto-save fires |
| **Idle** | Save file exists, no save/load in progress | Save file on disk, systems running from loaded state | Auto-save trigger fires or Load requested |
| **Saving** | Auto-save trigger fired | Serialize all system states, write backup, write save file. Block triggers during write. | Write completes (success or failure) |
| **Loading** | Player selects Continue | Read save file, validate, restore all system states | All systems restored, transition to Campaign Map |
| **Error** | Save file corrupted or version mismatch | Display warning to player. Offer New Game. | Player starts New Game or quits |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Campaign System** | Save reads/writes campaign state | `Campaign.get_save_data()` returns: current chapter, match index, match history, unlocked opponents, prologue/campaign complete flags. `Campaign.load_state(data)` restores from save. |
| **Reputation System** | Save reads/writes reputation | `Reputation.get_save_data()` returns: score. `Reputation.load_state(data)` restores score. |
| **Feud System** | Save reads/writes feud data | `Feud.get_all_feud_data()` returns: per-opponent states, encounter loss counts, trigger chapters. `Feud.load_feud_data(data)` restores all feud state. |
| **Scene Management** | Save triggers scene after load | After loading, Save System tells Scene Management to transition to Campaign Map at the correct chapter. |
| **Settings** | Save reads/writes settings | Settings are included in the save file for convenience. Settings manager exposes `get_settings()` and `apply_settings(data)`. |

## Formulas

No mathematical formulas. The Save System performs serialization and deserialization — no calculations. The only numeric operation is version comparison:

```
can_load = (save_version >= 1) AND (save_version <= current_version)
needs_migration = (save_version < current_version)
```

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|-------------------|-----------|
| App killed mid-save (write interrupted) | Backup file (`fidchell_save.backup.json`) survives. On next launch, detect corrupted primary save, fall back to backup. | Write-then-rename is atomic on most filesystems, but backup provides a safety net |
| Save file manually deleted by user | Same as first launch — No Save state, Continue disabled | Graceful degradation |
| Save file edited/tampered with | Validate JSON structure on load. If invalid, treat as corrupted — warn and offer New Game. No crash. | Mobile users rarely tamper, but corrupt files from cloud sync conflicts can look like tampering |
| Device runs out of storage | FileAccess write fails. Log error. Do not delete backup. Show subtle warning ("Progress could not be saved"). Retry on next trigger. | Storage failures shouldn't crash the game or lose existing data |
| Game update adds new save fields (v1 → v2) | Migration function adds new fields with sensible defaults. Existing data preserved. | Players shouldn't lose progress on update |
| Game downgrade (v2 save loaded by v1 app) | Refuse to load. Warn: "This save was created by a newer version." Offer New Game. | Prevents data corruption from missing fields |
| iCloud/Google backup restores old save over current | Treated as normal load — version check runs. If version matches, it loads (player may lose some progress). | Cloud sync is outside our control — version field helps detect issues |
| Player finishes campaign, then hits Continue | Load save with `campaign_complete: true`. Show campaign map in completed state with all opponents visible. Quick Play fully unlocked. | Completed campaigns are still valid saves |
| Auto-save fires during scene transition | Save writes asynchronously. Scene transition proceeds. If save fails, retry on next trigger. | Saving should never block gameplay |
| Settings saved but campaign not started yet | Save file exists with settings only, campaign block at defaults. Continue loads to pre-Prologue state. | Settings changes before New Game should persist |

## Dependencies

| System | Direction | Nature | Interface |
|--------|-----------|--------|-----------|
| **Campaign System** | This depends on | Hard — Campaign provides the primary save data | `get_save_data()`, `load_state(data)` |
| **Reputation System** | This depends on | Hard — Reputation provides score for persistence | `get_save_data()`, `load_state(data)` |
| **Feud System** | This depends on | Hard — Feud provides per-opponent state data | `get_all_feud_data()`, `load_feud_data(data)` |
| **Scene Management** | This uses | Soft — Save triggers scene transition after load | `change_scene("campaign_map")` |

**This system depends on:** Campaign System (hard), Reputation System (hard), Feud System (hard).

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|--------------------|--------------------|
| `save_slot_count` | 1 | 1–3 | Multiple campaigns — more complexity, save slot UI needed | Single campaign — simpler, no slot management |
| `auto_save_on_exit` | false | true/false | Saves when app backgrounds — less risk of lost progress | Only saves at defined triggers — simpler, predictable |
| `backup_count` | 1 | 0–3 | More backups — more recovery options, more storage | No backup — smaller footprint, more risk |
| `save_format` | JSON | JSON / binary | JSON: debuggable, larger. Binary: smaller, harder to inspect | N/A — format choice, not scalar |

## Acceptance Criteria

- [ ] Auto-save fires after every match result (win or loss processed)
- [ ] Auto-save fires after chapter transitions
- [ ] Continue correctly restores: chapter, match position, match history, reputation, feud states
- [ ] Continue button is disabled/hidden when no save file exists
- [ ] New Game shows confirmation dialog when a save exists
- [ ] New Game erases save and starts Prologue with clean state
- [ ] Corrupted save file shows warning and offers New Game — no crash
- [ ] Backup file is created before each save write
- [ ] Save version migration works (v1 → v2 adds new fields with defaults)
- [ ] Future version save is refused with clear warning
- [ ] Settings persist in save file and restore on load
- [ ] Campaign complete flag persists — completed campaigns remain loadable
- [ ] Save file uses `user://` for platform-appropriate local storage
- [ ] All save/load operations are non-blocking — no frame hitches during save
- [ ] Save file size stays under 50KB for the full campaign

## Open Questions

| Question | Owner | Target Resolution | Resolution |
|----------|-------|-------------------|-----------|
| Should settings be in the save file or a separate preferences file? Separate file means settings survive New Game. | UX Designer | Implementation | — |
| Should we support iCloud/Google Play save sync for cross-device play? Adds significant complexity. | Technical Director | Post-launch | — |
| Should there be a "delete save data" option in Settings for GDPR/privacy compliance? | Producer | Release planning | — |
