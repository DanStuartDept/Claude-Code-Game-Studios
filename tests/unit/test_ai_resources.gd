## GdUnit4 tests for AI Resources (S1-06)
##
## Covers S1-06 acceptance criteria:
## - Profile loads from .tres
## - AI uses loaded personality weights
## - OpponentProfile.apply_to() configures AI correctly
## - AIPersonalityData exports correct values
class_name TestAIResources
extends GdUnitTestSuite


const BoardRulesScript := preload("res://src/core/board_rules.gd")
const AISystemScript := preload("res://src/core/ai_system.gd")
const AIPersonalityScript := preload("res://src/data/ai_personality.gd")
const OpponentProfileScript := preload("res://src/data/opponent_profile.gd")

var _board: Node
var _ai: Node


func before_test() -> void:
	_board = BoardRulesScript.new()
	add_child(_board)
	_ai = AISystemScript.new()
	add_child(_ai)


func after_test() -> void:
	_ai.queue_free()
	_board.queue_free()


# ---------------------------------------------------------------------------
# AIPersonalityData loads from .tres
# ---------------------------------------------------------------------------

func test_erratic_personality_loads_from_tres() -> void:
	var pers: Resource = load("res://assets/data/ai/erratic.tres")
	assert_object(pers).is_not_null()
	assert_bool(pers is AIPersonalityData).is_true()


func test_erratic_personality_has_correct_name() -> void:
	var pers: AIPersonalityData = load("res://assets/data/ai/erratic.tres") as AIPersonalityData
	assert_str(pers.personality_name).is_equal("Erratic")


func test_erratic_personality_has_balanced_weights() -> void:
	var pers: AIPersonalityData = load("res://assets/data/ai/erratic.tres") as AIPersonalityData
	assert_float(pers.w_material).is_equal(1.0)
	assert_float(pers.w_king_freedom).is_equal(1.0)
	assert_float(pers.w_king_proximity).is_equal(1.0)
	assert_float(pers.w_board_control).is_equal(1.0)
	assert_float(pers.w_threat).is_equal(1.0)


func test_erratic_personality_has_disruption_chance() -> void:
	var pers: AIPersonalityData = load("res://assets/data/ai/erratic.tres") as AIPersonalityData
	assert_float(pers.erratic_disruption_chance).is_equal(0.3)


# ---------------------------------------------------------------------------
# OpponentProfile loads from .tres
# ---------------------------------------------------------------------------

func test_seanan_profile_loads_from_tres() -> void:
	var profile: Resource = load("res://assets/data/opponents/seanan.tres")
	assert_object(profile).is_not_null()
	assert_bool(profile is OpponentProfile).is_true()


func test_seanan_profile_has_correct_identity() -> void:
	var profile: OpponentProfile = load("res://assets/data/opponents/seanan.tres") as OpponentProfile
	assert_str(profile.character_name).is_equal("Séanán na Farraige")
	assert_str(profile.character_id).is_equal("seanan")
	assert_int(profile.difficulty).is_equal(1)


func test_seanan_profile_has_personality() -> void:
	var profile: OpponentProfile = load("res://assets/data/opponents/seanan.tres") as OpponentProfile
	assert_object(profile.personality).is_not_null()
	assert_bool(profile.personality is AIPersonalityData).is_true()
	assert_str(profile.personality.personality_name).is_equal("Erratic")


func test_seanan_profile_has_description() -> void:
	var profile: OpponentProfile = load("res://assets/data/opponents/seanan.tres") as OpponentProfile
	assert_str(profile.description).is_equal("Plays by feel, flashes of accidental brilliance")


# ---------------------------------------------------------------------------
# OpponentProfile.apply_to() configures AI correctly
# ---------------------------------------------------------------------------

func test_apply_to_sets_difficulty() -> void:
	_board.start_match(_board.MatchMode.STANDARD, _board.Side.DEFENDER)
	_ai.configure(_board, _board.Side.ATTACKER)

	var profile: OpponentProfile = load("res://assets/data/opponents/seanan.tres") as OpponentProfile
	profile.apply_to(_ai)

	assert_int(_ai.difficulty).is_equal(1)
	assert_int(_ai.search_depth).is_equal(1)


func test_apply_to_sets_personality_weights() -> void:
	_board.start_match(_board.MatchMode.STANDARD, _board.Side.DEFENDER)
	_ai.configure(_board, _board.Side.ATTACKER)

	var profile: OpponentProfile = load("res://assets/data/opponents/seanan.tres") as OpponentProfile
	profile.apply_to(_ai)

	assert_float(_ai.w_material).is_equal(1.0)
	assert_float(_ai.w_king_freedom).is_equal(1.0)
	assert_float(_ai.w_king_proximity).is_equal(1.0)
	assert_float(_ai.w_board_control).is_equal(1.0)
	assert_float(_ai.w_threat).is_equal(1.0)


func test_apply_to_sets_erratic_disruption() -> void:
	_board.start_match(_board.MatchMode.STANDARD, _board.Side.DEFENDER)
	_ai.configure(_board, _board.Side.ATTACKER)

	var profile: OpponentProfile = load("res://assets/data/opponents/seanan.tres") as OpponentProfile
	profile.apply_to(_ai)

	assert_float(_ai.erratic_disruption_chance).is_equal(0.3)


# ---------------------------------------------------------------------------
# AI uses loaded personality weights in gameplay
# ---------------------------------------------------------------------------

func test_ai_returns_valid_move_with_profile() -> void:
	_board.start_match(_board.MatchMode.STANDARD, _board.Side.DEFENDER)
	_ai.configure(_board, _board.Side.ATTACKER)

	var profile: OpponentProfile = load("res://assets/data/opponents/seanan.tres") as OpponentProfile
	profile.apply_to(_ai)

	var move: Dictionary = _ai.select_move()
	assert_bool(move.is_empty()).is_false()


# ---------------------------------------------------------------------------
# AIPersonalityData can be created programmatically
# ---------------------------------------------------------------------------

func test_personality_data_defaults() -> void:
	var pers := AIPersonalityData.new()
	assert_str(pers.personality_name).is_equal("Balanced")
	assert_float(pers.w_material).is_equal(1.0)
	assert_float(pers.erratic_disruption_chance).is_equal(0.0)


func test_opponent_profile_defaults() -> void:
	var profile := OpponentProfile.new()
	assert_str(profile.character_name).is_equal("")
	assert_str(profile.character_id).is_equal("")
	assert_int(profile.difficulty).is_equal(1)
	assert_object(profile.personality).is_null()
