extends GutTest

const LIGHT_TABLE_SCRIPT := preload("res://scripts/ui/light_table.gd")
const RITUAL_SCRIPT := preload("res://scripts/ui/ritual.gd")


func before_each() -> void:
	GameState.reset_run()
	Palette.reset()


func test_light_table_boots() -> void:
	var scene := load("res://scenes/light_table.tscn") as PackedScene
	var table := scene.instantiate()
	add_child_autofree(table)
	await wait_process_frames(2)
	assert_not_null(table.get_node_or_null("%TraceSheet"))
	assert_not_null(table.get_node_or_null("%Target"))
	assert_not_null(table.get_node_or_null("%OffsetLabel"))
	assert_false(table.get_node("%Result").visible)


func test_light_table_snap_threshold() -> void:
	assert_true(LIGHT_TABLE_SCRIPT.is_within_snap(0.0))
	assert_true(LIGHT_TABLE_SCRIPT.is_within_snap(64.0))
	assert_false(LIGHT_TABLE_SCRIPT.is_within_snap(64.1))


func test_developing_progress_clamps_and_drives_shader() -> void:
	var scene := load("res://scenes/developing.tscn") as PackedScene
	var room := scene.instantiate()
	add_child_autofree(room)
	await wait_process_frames(2)
	var plate: DevelopingPlate = room.get_node("%Plate")
	assert_not_null(plate.material)
	room.set_progress(0.42)
	assert_almost_eq(room.get_progress(), 0.42, 0.001)
	assert_almost_eq(room.get_node("%ProgressBar").value, 0.42, 0.001)
	assert_eq(room.get_node("%PercentLabel").text, "42%")
	assert_almost_eq(float(plate.material.get_shader_parameter("progress")), 0.42, 0.001)
	room.set_progress(1.5)
	assert_eq(room.get_progress(), 1.0)


func test_verdict_mapping_and_canonical_doubt() -> void:
	assert_eq(RITUAL_SCRIPT.verdict_for(0), "true")
	assert_eq(RITUAL_SCRIPT.verdict_for(1), "false")
	assert_eq(RITUAL_SCRIPT.verdict_for(2), "doubt")
	assert_eq(RITUAL_SCRIPT.verdict_for(3), "")
	assert_true(RITUAL_SCRIPT.is_canonical(2))
	assert_false(RITUAL_SCRIPT.is_canonical(0))
	assert_false(RITUAL_SCRIPT.is_canonical(1))


func test_ritual_rejects_wrong_voice_then_seals_doubt() -> void:
	var scene := load("res://scenes/ritual.tscn") as PackedScene
	var ritual := scene.instantiate()
	add_child_autofree(ritual)
	await wait_process_frames(2)
	assert_false(ritual.get_node("%Seal").visible)

	ritual._on_choice(0)
	assert_almost_eq(Palette.saturation, 0.25, 0.001)
	assert_false(GameState.verdicts.has("dossier_wudu"))

	ritual._on_choice(2)
	assert_eq(str(GameState.verdicts.get("dossier_wudu", "")), "doubt")
	assert_true(ritual.get_node("%Seal").visible)
	assert_almost_eq(Palette.saturation, 0.35, 0.001)


func test_scene_view_disables_collected_hotspots() -> void:
	GameState.collect_evidence("card_chart_splice", 10)
	GameState.collect_evidence("card_plate_press", 10)
	var scene := load("res://scenes/scene_view.tscn") as PackedScene
	var view := scene.instantiate()
	add_child_autofree(view)
	await wait_process_frames(2)
	assert_true(view.get_node("%HotspotPlate").disabled)
	assert_true(view.get_node("%HotspotChart").disabled)
	assert_eq(view.get_node("%Hint").text, "现场已清点 · 回到档案桌收尾")
