extends GutTest


func before_each() -> void:
	GameState.reset_run()
	Palette.reset()


func test_archive_desk_scene_boots() -> void:
	var scene := load("res://scenes/archive_desk.tscn") as PackedScene
	var desk := scene.instantiate()
	add_child_autofree(desk)
	await wait_process_frames(2)
	assert_not_null(desk.get_node_or_null("%BtnEnter"))
	assert_not_null(desk.get_node_or_null("%ProgressLabel"))
	assert_not_null(desk.get_node_or_null("%BtnRitual"))
	assert_true(desk.get_node("%BtnEnter").text in ["打开卷宗", "继续卷宗"])


func test_ritual_button_appears_when_all_seven_cards_collected() -> void:
	var scene := load("res://scenes/archive_desk.tscn") as PackedScene
	var desk := scene.instantiate()
	add_child_autofree(desk)
	await wait_process_frames(2)
	var ritual: Button = desk.get_node("%BtnRitual")
	assert_false(ritual.visible)
	for card_id in Chapter.required_cards():
		GameState.collect_evidence(card_id, 10)
	desk._refresh()
	assert_true(ritual.visible)
	GameState.record_verdict("dossier_wudu", "doubt")
	desk._refresh()
	assert_false(ritual.visible)


func test_chapter_index_boots_with_seven_scene_rows() -> void:
	var scene := load("res://scenes/chapter_index.tscn") as PackedScene
	var index := scene.instantiate()
	add_child_autofree(index)
	await wait_process_frames(2)
	var rows := index.get_node("%SceneList").get_children()
	assert_eq(rows.size(), 7)
	assert_true(rows[0] is Button)
	assert_false((rows[0] as Button).disabled)
	assert_true((rows[1] as Button).disabled)
	assert_not_null(index.get_node_or_null("%ProgressLabel"))


func test_scene_view_boots_with_dynamic_hotspots() -> void:
	GameState.current_scene_id = "alley"
	var scene := load("res://scenes/scene_view.tscn") as PackedScene
	var view := scene.instantiate()
	add_child_autofree(view)
	await wait_process_frames(2)
	assert_not_null(view.get_node_or_null("%Hotspots"))
	assert_not_null(view.get_node_or_null("%Portholes"))
	assert_false(view.get_node("%EvidenceSheet").visible)
	var buttons := _hotspot_buttons(view.get_node("%Hotspots"))
	assert_eq(buttons.size(), 1)
	assert_eq(view.get_node("%Portholes").get_child_count(), 0)
	assert_true(view.get_node("%Hint").text.contains("巷口"))


func _hotspot_buttons(container: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child in container.get_children():
		if child is Button:
			result.append(child)
	return result
