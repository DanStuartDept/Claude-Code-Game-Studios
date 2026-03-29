# Sprint 6 — Balance, QA & Observability

## Context

Sprint 5 achieved Beta: feature-complete, content-complete, 311 tests passing. The game *works* but we can't yet *observe* it at scale. The user wants to launch the game via Godot MCP, autoplay the full campaign, read structured logs, and analyze balance/engagement — all without human input.

**Key blocker**: The Godot MCP `run_project` tool can't pass `--autoplay` CLI args. We need an alternative trigger.

## Plan

### Phase 1: Make Autoplay Work via MCP (Sessions 1-2)

**S6-01: File-based autoplay trigger** (1 session)
- Check for `user://autoplay.cfg` at startup in `main_menu.gd` (alongside existing `--autoplay` CLI check)
- Parse simple config: `fast=true/false`, `runs=1`
- Pass config to `campaign_map.gd` and `match_controller.gd` via `SceneManager.scene_data` or a shared autoload dict
- MCP workflow: write cfg to `~/Library/Application Support/Godot/app_userdata/Fidchell/autoplay.cfg` via Bash, then `run_project`
- Files: `src/ui/main_menu.gd`, `src/ui/campaign_map.gd`, `src/ui/match_controller.gd`, `src/ui/dialogue_overlay.gd`

**S6-02: Fast autoplay mode** (0.5 session)
- When `fast=true` in autoplay.cfg: dialogue advance 0.3s (from 2.5s), campaign delay 0.3s (from 2.0s), match result pause 0.3s (from 2.0s), AI think time 0.05s
- Target: full 18-match campaign in under 10 minutes
- Files: same as S6-01

**S6-06: Fix `target_db` crossfade bug** (0.25 session)
- `audio_system.gd:607` — change `0.0` to `target_db` so crossfade respects music volume setting
- File: `src/core/audio_system.gd`

**S6-05: Fix Unicode parsing errors** (0.5 session)
- Investigate UTF-8 errors from Irish characters (é, ó, í, á) in dialogue/locale JSON
- Likely fix: ensure files are UTF-8 without BOM, verify `FileAccess` read encoding
- Files: `assets/data/campaign/dialogue_lines.json`, `assets/data/locales/en.json`, loaders in `dialogue_system.gd` and `locale_system.gd`

### Phase 2: Structured Logging (Sessions 3-5)

**S6-03: GameLogger autoload — per-match recording** (1.5 sessions)
- New `src/core/game_logger.gd` autoload, registered in `project.godot`
- Listens to `CampaignSystem.match_result_processed` and `ReputationSystem.reputation_changed`
- Writes JSON Lines to `user://game_log.jsonl`
- Per-match record: `match_id`, `chapter`, `order_in_chapter`, `opponent_id`, `opponent_difficulty`, `match_type`, `winner`, `win_reason`, `move_count`, `pieces_remaining`, `reputation_earned`, `reputation_breakdown`, `reputation_total`, `timestamp`
- File: new `src/core/game_logger.gd`, `project.godot`

**S6-04: Campaign summary report** (1 session)
- At campaign completion, GameLogger writes `user://campaign_summary.json`
- Contents: total matches, wins/losses, per-chapter breakdown (avg move count, avg difficulty, rep earned), overall stats (fastest/slowest win, rep by bonus type), player-AI config
- Print summary to console with `[SUMMARY]` tag for MCP `get_debug_output` polling
- File: `src/core/game_logger.gd`

**S6-07: MCP workflow validation + docs** (0.5 session)
- Execute the full workflow: write cfg → run_project → poll debug output for `[SUMMARY]` → stop_project → read log files
- Document in `docs/autoplay-workflow.md`

### Phase 3: Balance & Engagement Review (Sessions 6-8)

**S6-08: Player-side AI scaling** (0.5 session)
- Scale player-AI difficulty by chapter: ch0=1, ch1=2, ch2=3, ch3=4, ch4=5
- Better simulates a learning human player for representative balance data
- File: `src/ui/match_controller.gd`

**S6-09: Balance analysis** (1.5 sessions)
- Run 3+ full autoplay campaigns with scaled player AI
- Analyze: win rates per opponent, move count distributions, rep accumulation rate, chapter gating feel, difficulty curve smoothness
- Document findings + tuning recommendations in `docs/balance-analysis.md`

**S6-10: Balance tuning** (1 session)
- Apply adjustments from S6-09 (rep thresholds, AI difficulty, bonus values)
- Re-run autoplay to confirm improvements
- Files: `assets/data/campaign/reputation_config.json`, `assets/data/campaign/campaign_schedule.json`, opponent `.tres` files

**S6-11: Engagement review** (0.5 session)
- Qualitative review: match length sweet spot (15-40 moves), difficulty ramp, close games, boss distinctiveness
- Document in `docs/engagement-review.md`

### Nice to Have

**S6-12: Multi-run autoplay** (1 session) — `runs=N` in cfg, append with `run_id`, aggregate stats
**S6-13: Win rate heatmap** (0.5 session) — per-match win rates across runs, flag outliers
**S6-14: Console log cleanup** (0.5 session) — consistent `[TAG]` prefixes, gate verbose logging behind autoplay

## Implementation Order

```
Session 1:      S6-01 (Autoplay trigger) + S6-06 (Fix crossfade bug)
Session 2:      S6-02 (Fast mode) + S6-05 (Fix Unicode errors)
Session 3-4:    S6-03 (GameLogger per-match recording)
Session 5:      S6-04 (Campaign summary) + S6-07 (MCP workflow test)
Session 6:      S6-08 (Player-AI scaling) + first autoplay run
Session 7:      S6-09 (Balance analysis — 3+ runs)
Session 8:      S6-10 (Balance tuning) + S6-11 (Engagement review)
Buffer:         S6-12, S6-13, S6-14
```

## Key Files

| File | Changes |
|------|---------|
| `src/ui/main_menu.gd` | Add `user://autoplay.cfg` check |
| `src/ui/match_controller.gd` | Fast timing, player-AI scaling, log hooks |
| `src/ui/campaign_map.gd` | Fast timing, summary trigger |
| `src/ui/dialogue_overlay.gd` | Fast dialogue advance |
| `src/core/audio_system.gd` | Fix `target_db` on line 607 |
| `src/core/game_logger.gd` | **New** — GameLogger autoload |
| `project.godot` | Register GameLogger autoload |
| `assets/data/campaign/dialogue_lines.json` | UTF-8 encoding fix |
| `assets/data/locales/en.json` | UTF-8 encoding fix |
| `docs/autoplay-workflow.md` | **New** — MCP workflow docs |
| `docs/balance-analysis.md` | **New** — Balance findings |
| `docs/engagement-review.md` | **New** — Engagement findings |
| `production/sprints/sprint-06.md` | **New** — Sprint plan |

## Verification

1. Write `autoplay.cfg` with `fast=true` to `~/Library/Application Support/Godot/app_userdata/Fidchell/`
2. Launch via `mcp__godot__run_project`
3. Poll `mcp__godot__get_debug_output` — expect `[SUMMARY]` within ~10 minutes
4. Stop project, read `game_log.jsonl` and `campaign_summary.json` from user data dir
5. Verify 0 Unicode warnings, 0 unused variable warnings in error output
6. Run GdUnit4 suite — confirm 311+ tests, 0 failures

## Definition of Done

- [x] Game enters autoplay via file trigger (no CLI args needed)
- [x] Full campaign completes in fast mode in under 10 minutes
- [x] Every match produces a JSON line in `game_log.jsonl`
- [x] Campaign summary written to file and console
- [x] MCP workflow documented and validated
- [x] Zero Unicode/encoding warnings
- [x] Zero unused variable warnings
- [x] Balance analysis document with tuning recommendations
- [x] Engagement review document
- [x] All tests pass (311+, 0 failures)
