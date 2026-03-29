# Sprint 6 — Balance, QA & Observability

> **Status**: Complete
> **Goal**: Make the full campaign observable, measurable, and verifiable through automated play with structured logging and balance analysis
> **Milestone**: QA (post-Beta, pre-Release)
> **Created**: 2026-03-29

## Sprint Goal

The Beta is feature-complete and content-complete with 311 tests passing. Sprint 6
shifts from building to verifying. The game must become machine-readable: Claude Code
launches it via Godot MCP, the full campaign auto-plays without CLI args, structured
logs capture every match outcome, and a summary report enables balance analysis. Known
warnings and parsing errors get fixed. The autoplay system gets a fast mode so a full
18-match campaign completes in minutes, not hours. By the end, we can answer: "Is this
game balanced? Is it engaging? Does it crash?"

## What This Sprint Proves

"Can we observe and measure the game we built?" Every match produces structured data.
The full campaign can be auto-played and analyzed without human intervention. Balance
metrics are visible and actionable.

## Capacity

Solo project, session-based. Sprint 5: 16 tasks across ~10 sessions. Sprint 6 is
lighter on content creation but heavier on instrumentation and analysis.

- Estimated sessions: 10
- Buffer (20%): ~2 sessions
- Available: ~8 sessions of planned work

## Tasks

### Must Have (Critical Path)

| ID | Task | System | Est. Sessions | Dependencies | Acceptance Criteria |
|----|------|--------|---------------|--------------|---------------------|
| S6-01 | **File-based autoplay trigger** — Check for `user://autoplay.cfg` at startup alongside existing `--autoplay` CLI flag. Parse config: `fast=true/false`, `runs=1`. All UI files (main_menu, campaign_map, match_controller, dialogue_overlay) check this trigger. MCP workflow: write cfg file before `run_project` | Core / Debug | 1 | — | Game enters autoplay when `autoplay.cfg` exists; MCP workflow works; existing --autoplay CLI still works |
| S6-02 | **Fast autoplay mode** — When `fast=true` in config: dialogue 0.3s (from 2.5s), campaign delay 0.3s (from 2.0s), match result pause 0.3s (from 2.0s), AI think time 0.05s. Keep normal timing as default | Core / Debug | 0.5 | S6-01 | Full campaign completes in under 10 minutes in fast mode; normal autoplay timing unchanged |
| S6-03 | **GameLogger autoload — per-match recording** — New `game_logger.gd` autoload. Listens to CampaignSystem.match_result_processed and ReputationSystem.reputation_changed. Writes JSON Lines to `user://game_log.jsonl`. Per-match: match_id, chapter, opponent_id, difficulty, match_type, winner, win_reason, move_count, pieces_remaining, rep_earned, rep_breakdown, rep_total, timestamp | Observability | 1.5 | — | Every match appends a JSON line; file is valid JSON Lines; all fields populated |
| S6-04 | **Campaign summary report** — At campaign completion, GameLogger writes `user://campaign_summary.json` with total stats, per-chapter breakdown, fastest/slowest win, rep by bonus type. Print to console with `[SUMMARY]` tag | Observability | 1 | S6-03 | Summary file written; console shows full summary; stats accurate |
| S6-05 | **Fix Unicode parsing errors** — Investigate UTF-8 errors from Irish characters in dialogue/locale JSON. Ensure files are UTF-8 without BOM | Core / i18n | 0.5 | — | Zero UTF-8 warnings in Godot console; Irish characters display correctly |
| S6-06 | **Fix crossfade volume bug** — `audio_system.gd:607` uses `0.0` instead of computed `target_db`. Crossfade ignores player volume setting. Fix to use `target_db` | Audio | 0.25 | — | No unused variable warning; crossfade respects volume setting |
| S6-07 | **MCP autoplay integration test** — Validate full workflow: write cfg → run_project → poll for `[SUMMARY]` → stop_project → read log files. Document in `docs/autoplay-workflow.md` | QA / Docs | 0.5 | S6-01, S6-02, S6-03, S6-04 | Workflow executes end-to-end; summary readable by Claude Code |

### Should Have

| ID | Task | System | Est. Sessions | Dependencies | Acceptance Criteria |
|----|------|--------|---------------|--------------|---------------------|
| S6-08 | **Player-side AI scaling** — Scale player-AI difficulty by chapter: ch0=1, ch1=2, ch2=3, ch3=4, ch4=5 (currently hardcoded to 2). Simulates a learning human player | AI / Match | 0.5 | — | Player-AI difficulty increases per chapter; logged in `[MATCH]` output |
| S6-09 | **Balance analysis pass** — Run 3+ autoplay campaigns. Analyze win rates, move counts, rep progression, difficulty curve. Document findings in `docs/balance-analysis.md` | Balance / Design | 1.5 | S6-03, S6-04, S6-07, S6-08 | Analysis doc with 3+ data points per match; specific tuning recommendations |
| S6-10 | **Balance tuning implementation** — Apply adjustments from S6-09: rep thresholds, AI difficulty, bonus values. Re-run autoplay to confirm | Balance / Data | 1 | S6-09 | Updated config values; re-run confirms improved metrics |
| S6-11 | **Engagement review** — Qualitative review: match length (15-40 moves ideal), difficulty ramp, close games, boss distinctiveness. Document in `docs/engagement-review.md` | Design / QA | 0.5 | S6-04, S6-07 | Review doc with 3+ specific observations and proposed fixes |

### Nice to Have

| ID | Task | System | Est. Sessions | Dependencies | Acceptance Criteria |
|----|------|--------|---------------|--------------|---------------------|
| S6-12 | **Multi-run autoplay** — Extend cfg to `runs=N`. After campaign completes, reset and run again. Append with `run_id`. Aggregate stats in summary | Observability | 1 | S6-01, S6-03, S6-04 | Multiple runs complete; each run has distinct run_id; aggregate stats |
| S6-13 | **Win rate heatmap logging** — Per-match win rate tracking across runs. Flag matches with <30% or >90% win rate as balance issues | Observability | 0.5 | S6-12 | Win rate table in summary; outlier matches flagged |
| S6-14 | **Console log cleanup** — Consistent `[TAG]` prefix on all print() statements. Gate verbose logging behind autoplay mode | Code Quality | 0.5 | — | All prints use consistent tags; normal play has minimal noise |

## Carryover from Previous Sprint

None — Sprint 5 completed all tiers.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| MCP run_project may not support writing files before launch | Medium | High | Write cfg via Bash to Godot user data path before launching |
| Fast autoplay may expose race conditions in scene transitions | Medium | Medium | Keep normal-speed fallback; add null/freed node guards |
| AI-vs-AI results may not represent human play | High | Medium | Scale player-AI per chapter (S6-08); document limitations |
| Unicode fix may require re-exporting dialogue files | Low | Low | Godot 4.6 JSON.parse() handles UTF-8; likely BOM issue |
| Balance tuning cascades (rep thresholds → gating → difficulty curve) | Medium | Medium | One change at a time; re-run autoplay after each |

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

## Definition of Done for this Sprint

- [x] All Must Have tasks (S6-01 through S6-07) completed
- [x] Game enters autoplay mode without CLI args (file-based trigger works)
- [x] Full campaign completes in fast autoplay mode in under 10 minutes
- [x] Every match produces a structured JSON line in `game_log.jsonl`
- [x] Campaign summary report written to file and printed to console
- [x] MCP workflow documented and validated end-to-end
- [x] Zero Unicode parsing errors in console output
- [x] Zero unused variable warnings in console output
- [x] All existing tests still pass (311+ tests, 0 errors, 0 failures)
- [x] Code follows ADR-0001 architecture
