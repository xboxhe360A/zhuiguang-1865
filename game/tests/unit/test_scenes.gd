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
	assert_true(desk.get_node("%BtnEnter").text in ["打开卷宗", "继续卷宗"])


func test_scene_view_boots_with_hud() -> void:
	var scene := load("res://scenes/scene_view.tscn") as PackedScene
	var view := scene.instantiate()
	add_child_autofree(view)
	await wait_process_frames(2)
	assert_not_null(view.get_node_or_null("%Hotspot"))
	assert_not_null(view.get_node_or_null("%Portholes"))
	assert_false(view.get_node("%EvidenceSheet").visible)
	assert_eq(view.get_node("%Portholes").get_child_count(), 5)
