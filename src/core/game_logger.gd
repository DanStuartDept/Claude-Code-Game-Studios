## GameLogger — Autoload that records per-match data to JSON Lines.
##
## Listens to CampaignSystem.match_result_processed and
## ReputationSystem.reputation_changed to build structured match records.
## Writes one JSON object per line to user://game_log.jsonl.
## At campaign completion, writes a summary to user://campaign_summary.json.
##
## Architecture: Core Layer (ADR-0001). Depends on CampaignSystem, ReputationSystem.
## See: production/sprints/sprint-06-plan.md (S6-03, S6-04)
extends Node


# --- Configuration ---

const LOG_PATH: String = "user://game_log.jsonl"
const SUMMARY_PATH: String = "user://campaign_summary.json"


# --- State ---

## Running match counter for the current session.
var _match_count: int = 0

## Pending reputation data from the most recent reputation_changed signal.
## Cleared after being consumed by the match_result_processed handler.
var _pending_rep: Dictionary = {}

## All match records for the current campaign (for summary generation).
var _match_records: Array[Dictionary] = []

## Campaign start timestamp.
var _campaign_start_time: String = ""


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	var campaign: Node = get_node_or_null("/root/CampaignSystem")
	if campaign != null:
		campaign.match_result_processed.connect(_on_match_result_processed)
		campaign.campaign_completed.connect(_on_campaign_completed)

	var reputation: Node = get_node_or_null("/root/ReputationSystem")
	if reputation != null:
		reputation.reputation_changed.connect(_on_reputation_changed)

	_campaign_start_time = Time.get_datetime_string_from_system(true)


# ---------------------------------------------------------------------------
# Signal Handlers
# ---------------------------------------------------------------------------

## Cache reputation data — arrives before match_result_processed.
func _on_reputation_changed(new_total: int, earned: int, breakdown: Dictionary) -> void:
	_pending_rep = {
		"reputation_earned": earned,
		"reputation_breakdown": breakdown,
		"reputation_total": new_total,
	}


## Record a complete match entry when the campaign processes the result.
func _on_match_result_processed(result: Dictionary) -> void:
	_match_count += 1

	var campaign: Node = get_node_or_null("/root/CampaignSystem")
	if campaign == null:
		return

	# The signal fires after current_match_in_chapter may have advanced,
	# so look up the match that just completed (previous index for wins/scripted).
	var player_won: bool = (result.get("winner", -1) == 1)
	var ch_matches: Array = campaign._get_chapter_matches(campaign.current_chapter)
	var completed_idx: int = campaign.current_match_in_chapter
	if player_won or result.get("match_type", "") == "scripted":
		completed_idx = maxi(campaign.current_match_in_chapter - 1, 0)
	var entry: Dictionary = ch_matches[completed_idx] if completed_idx < ch_matches.size() else {}

	# Load opponent profile from the entry
	var opponent: Resource = null
	var opp_path: String = entry.get("opponent_path", "")
	if opp_path != "" and ResourceLoader.exists(opp_path):
		opponent = load(opp_path)

	# Build the match record
	var record: Dictionary = {
		"match_id": entry.get("match_id", "match_%d" % _match_count),
		"chapter": campaign.current_chapter,
		"order_in_chapter": completed_idx,
		"opponent_id": opponent.character_id if opponent != null else "",
		"opponent_difficulty": opponent.difficulty if opponent != null else 0,
		"match_type": entry.get("match_type", "standard"),
		"winner": "defender" if result.get("winner", -1) == 1 else "attacker",
		"win_reason": _win_reason_string(result.get("reason", 0)),
		"move_count": result.get("move_count", 0),
		"pieces_remaining": result.get("pieces_remaining", {}),
		"timestamp": Time.get_datetime_string_from_system(true),
	}

	# Merge reputation data if available (only for wins)
	if not _pending_rep.is_empty():
		record.merge(_pending_rep)
		_pending_rep = {}
	else:
		record["reputation_earned"] = 0
		record["reputation_breakdown"] = {}
		var rep: Node = get_node_or_null("/root/ReputationSystem")
		record["reputation_total"] = rep.get_reputation() if rep != null else 0

	_match_records.append(record)
	_write_jsonl(record)

	print("[LOG] Match #%d: %s vs %s — %s (%s) in %d moves | Rep: +%d (total: %d)" % [
		_match_count,
		"player",
		record["opponent_id"],
		record["winner"],
		record["win_reason"],
		record["move_count"],
		record.get("reputation_earned", 0),
		record.get("reputation_total", 0),
	])


## Generate and write campaign summary on completion.
func _on_campaign_completed() -> void:
	_write_campaign_summary()


# ---------------------------------------------------------------------------
# File I/O
# ---------------------------------------------------------------------------

## Append a single JSON object as one line to the log file.
func _write_jsonl(record: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		# File doesn't exist yet — create it
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	else:
		file.seek_end()

	if file == null:
		push_warning("GameLogger: Could not open %s for writing" % LOG_PATH)
		return

	file.store_line(JSON.stringify(record))
	file.close()


## Write full campaign summary to JSON file and print to console.
func _write_campaign_summary() -> void:
	var campaign: Node = get_node_or_null("/root/CampaignSystem")
	var rep: Node = get_node_or_null("/root/ReputationSystem")

	var total_matches: int = _match_records.size()
	var wins: int = 0
	var losses: int = 0
	var total_moves: int = 0
	var fastest_win_moves: int = 999
	var slowest_win_moves: int = 0
	var rep_by_type: Dictionary = {}
	var chapter_stats: Dictionary = {}

	for record: Dictionary in _match_records:
		var is_win: bool = (record.get("winner", "") == "defender")
		if is_win:
			wins += 1
			var mc: int = record.get("move_count", 0)
			if mc < fastest_win_moves:
				fastest_win_moves = mc
			if mc > slowest_win_moves:
				slowest_win_moves = mc
		else:
			losses += 1

		total_moves += record.get("move_count", 0)

		# Per-chapter stats
		var ch: String = str(record.get("chapter", 0))
		if not chapter_stats.has(ch):
			chapter_stats[ch] = {
				"matches": 0, "wins": 0, "losses": 0,
				"total_moves": 0, "rep_earned": 0,
				"total_difficulty": 0,
			}
		chapter_stats[ch]["matches"] += 1
		chapter_stats[ch]["total_moves"] += record.get("move_count", 0)
		chapter_stats[ch]["total_difficulty"] += record.get("opponent_difficulty", 0)
		chapter_stats[ch]["rep_earned"] += record.get("reputation_earned", 0)
		if is_win:
			chapter_stats[ch]["wins"] += 1
		else:
			chapter_stats[ch]["losses"] += 1

		# Rep by bonus type
		var breakdown: Dictionary = record.get("reputation_breakdown", {})
		for key: String in breakdown:
			if not rep_by_type.has(key):
				rep_by_type[key] = 0
			rep_by_type[key] += int(breakdown[key])

	# Compute per-chapter averages
	var chapter_breakdown: Dictionary = {}
	for ch: String in chapter_stats:
		var cs: Dictionary = chapter_stats[ch]
		chapter_breakdown[ch] = {
			"matches": cs["matches"],
			"wins": cs["wins"],
			"losses": cs["losses"],
			"avg_moves": cs["total_moves"] / cs["matches"] if cs["matches"] > 0 else 0,
			"avg_difficulty": cs["total_difficulty"] / cs["matches"] if cs["matches"] > 0 else 0,
			"rep_earned": cs["rep_earned"],
		}

	if fastest_win_moves == 999:
		fastest_win_moves = 0

	var summary: Dictionary = {
		"campaign_start": _campaign_start_time,
		"campaign_end": Time.get_datetime_string_from_system(true),
		"total_matches": total_matches,
		"wins": wins,
		"losses": losses,
		"win_rate": float(wins) / total_matches if total_matches > 0 else 0.0,
		"total_moves": total_moves,
		"avg_moves_per_match": total_moves / total_matches if total_matches > 0 else 0,
		"fastest_win_moves": fastest_win_moves,
		"slowest_win_moves": slowest_win_moves,
		"final_reputation": rep.get_reputation() if rep != null else 0,
		"rep_by_bonus_type": rep_by_type,
		"chapter_breakdown": chapter_breakdown,
	}

	# Write to file
	var file: FileAccess = FileAccess.open(SUMMARY_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(summary, "\t"))
		file.close()

	# Print to console for MCP polling
	print("[SUMMARY] === Campaign Summary ===")
	print("[SUMMARY] Matches: %d (W:%d L:%d) | Win rate: %.0f%%" % [
		total_matches, wins, losses, summary["win_rate"] * 100.0])
	print("[SUMMARY] Moves: %d total, %d avg | Fastest win: %d | Slowest win: %d" % [
		total_moves, summary["avg_moves_per_match"], fastest_win_moves, slowest_win_moves])
	print("[SUMMARY] Final reputation: %d" % summary.get("final_reputation", 0))
	print("[SUMMARY] Rep breakdown: %s" % str(rep_by_type))
	for ch: String in chapter_breakdown:
		var cb: Dictionary = chapter_breakdown[ch]
		print("[SUMMARY]   Ch%s: %dW/%dL, avg %d moves, avg diff %.1f, +%d rep" % [
			ch, cb["wins"], cb["losses"], cb["avg_moves"],
			cb["avg_difficulty"], cb["rep_earned"]])
	print("[SUMMARY] === End Summary ===")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Convert WinReason enum to readable string.
func _win_reason_string(reason: int) -> String:
	match reason:
		1:
			return "king_escaped"
		2:
			return "king_captured"
		3:
			return "no_legal_moves"
	return "unknown"
