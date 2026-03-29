# Autoplay Workflow via Godot MCP

Automated campaign playthroughs for balance analysis and QA.

## Overview

The autoplay system runs the full 18-match campaign with AI controlling both
sides. It can be triggered via CLI args (`--autoplay`) or a config file
(`user://autoplay.cfg`). The file-based trigger is needed because the Godot
MCP `run_project` tool cannot pass CLI arguments.

## Config File

Create `autoplay.cfg` in the Godot user data directory:

```
# Autoplay configuration
fast=true
runs=1
```

| Key | Values | Default | Description |
|-----|--------|---------|-------------|
| `fast` | `true`/`false` | `false` | Reduces all delays (dialogue 0.3s, AI think 0.05s, transitions 0.3s) |
| `runs` | integer | `1` | Number of campaign runs (future: S6-12) |

### User Data Directory

| Platform | Path |
|----------|------|
| macOS | `~/Library/Application Support/Godot/app_userdata/Fidchell/` |
| Linux | `~/.local/share/godot/app_userdata/Fidchell/` |
| Windows | `%APPDATA%\Godot\app_userdata\Fidchell\` |

## MCP Workflow

### Step 1: Write Config

```bash
mkdir -p ~/Library/Application\ Support/Godot/app_userdata/Fidchell/
cat > ~/Library/Application\ Support/Godot/app_userdata/Fidchell/autoplay.cfg << 'EOF'
fast=true
runs=1
EOF
```

### Step 2: Launch Game

Use `mcp__godot__run_project` to start the game. The main menu detects
`autoplay.cfg` and immediately launches a new campaign.

### Step 3: Monitor Progress

Poll `mcp__godot__get_debug_output` periodically. Look for:

- `[MENU] Loaded autoplay.cfg: ...` — Config parsed successfully
- `[MENU] Auto-play detected, launching campaign...` — Campaign starting
- `[AUTOPLAY] Auto-challenge in ...` — Match flow progressing
- `[MATCH] === Match #N Result ===` — Individual match results
- `[LOG] Match #N: ...` — GameLogger recording
- `[SUMMARY] === Campaign Summary ===` — Campaign complete

### Step 4: Stop and Collect

After seeing `[SUMMARY]`, use `mcp__godot__stop_project` to stop the game.

Read output files from the user data directory:

- `game_log.jsonl` — One JSON object per line, one line per match
- `campaign_summary.json` — Aggregate stats for the full campaign

## Output Format

### game_log.jsonl (per-match)

```json
{"match_id":"ch0_m0","chapter":0,"order_in_chapter":0,"opponent_id":"murchadh","opponent_difficulty":3,"match_type":"scripted","winner":"attacker","win_reason":"king_captured","move_count":12,"pieces_remaining":{"attacker":6,"defender":3},"reputation_earned":0,"reputation_breakdown":{},"reputation_total":0,"timestamp":"2026-03-29T14:30:00"}
```

### campaign_summary.json

```json
{
  "campaign_start": "2026-03-29T14:25:00",
  "campaign_end": "2026-03-29T14:35:00",
  "total_matches": 18,
  "wins": 14,
  "losses": 4,
  "win_rate": 0.778,
  "total_moves": 450,
  "avg_moves_per_match": 25,
  "fastest_win_moves": 11,
  "slowest_win_moves": 48,
  "final_reputation": 62,
  "rep_by_bonus_type": {"base": 42, "boss": 12, "efficiency": 6, "rematch": 2},
  "chapter_breakdown": {
    "0": {"matches": 2, "wins": 1, "losses": 1, "avg_moves": 15, "avg_difficulty": 2, "rep_earned": 3},
    "1": {"matches": 4, "wins": 3, "losses": 1, "avg_moves": 22, "avg_difficulty": 2, "rep_earned": 12}
  }
}
```

## Timing Comparison

| Delay | Normal | Fast |
|-------|--------|------|
| Dialogue advance | 2.5s | 0.3s |
| Campaign map delay | 2.0s | 0.3s |
| AI think time | ~0.5s | 0.05s |
| Match result pause | 2.0s | 0.3s |
| Player AI turn delay | 0.15s | 0.05s |

Expected fast-mode campaign duration: 5-10 minutes for 18 matches.

## Cleanup

Remove the config file after autoplay to prevent it from triggering on
normal game launches:

```bash
rm ~/Library/Application\ Support/Godot/app_userdata/Fidchell/autoplay.cfg
```
