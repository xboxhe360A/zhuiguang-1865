extends GutTest

const TEST_SAVE := "user://test_save.json"


func before_each() -> void:
	GameState.reset_run()
	Palette.reset()


func after_all() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func test_collect_adds_weight_once() -> void:
	GameState.collect_evidence("card_a", 10)
	GameState.collect_evidence("card_a", 10)
	assert_eq(GameState.collected.size(), 1)
	assert_eq(GameState.completeness, 10)


func test_collect_clamps_completeness_at_100() -> void:
	GameState.collect_evidence("card_a", 70)
	GameState.collect_evidence("card_b", 70)
	assert_eq(GameState.completeness, 100)


func test_collect_emits_signals_once() -> void:
	watch_signals(GameState)
	GameState.collect_evidence("card_a", 10)
	GameState.collect_evidence("card_a", 10)
	assert_signal_emit_count(GameState, "evidence_collected", 1)
	assert_signal_emit_count(GameState, "completeness_changed", 1)


func test_verdict_records_valid_choice() -> void:
	watch_signals(GameState)
	GameState.record_verdict("dossier_wudu", "doubt")
	assert_eq(GameState.verdicts["dossier_wudu"], "doubt")
	assert_signal_emitted(GameState, "verdict_recorded")


func test_invalid_verdict_is_rejected() -> void:
	GameState.record_verdict("dossier_wudu", "maybe")
	assert_push_error("invalid verdict")
	assert_eq(GameState.verdicts.size(), 0)


func test_save_load_roundtrip() -> void:
	GameState.collect_evidence("card_a", 25)
	GameState.record_verdict("dossier_wudu", "true")
	Palette.set_saturation(0.72)
	assert_eq(GameState.save_to(TEST_SAVE), OK)

	GameState.reset_run()
	Palette.reset()
	assert_eq(GameState.load_from(TEST_SAVE), OK)
	assert_true(GameState.has_evidence("card_a"))
	assert_eq(GameState.verdicts["dossier_wudu"], "true")
	assert_eq(GameState.completeness, 25)
	assert_almost_eq(Palette.saturation, 0.72, 0.001)


func test_load_missing_file_returns_error() -> void:
	assert_eq(GameState.load_from("user://no_such_save.json"), ERR_FILE_NOT_FOUND)
