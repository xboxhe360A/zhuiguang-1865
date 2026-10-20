extends GutTest


func before_each() -> void:
	GameState.reset_run()
	Palette.reset()


func _field_scene(puzzle_id: String) -> Control:
	GameState.current_puzzle_id = puzzle_id
	var scene := load("res://scenes/field_puzzle.tscn") as PackedScene
	var view := scene.instantiate()
	add_child_autofree(view)
	await wait_process_frames(2)
	return view


func test_chapter_data_integrity() -> void:
	var definition: ChapterDef = Chapter.definition
	assert_not_null(definition)
	assert_eq(definition.scenes.size(), 7)
	assert_eq(definition.puzzles.size(), 11)
	var scene_ids: Dictionary = {}
	for scene in definition.scenes:
		var scene_id := str(scene.get("id", ""))
		assert_false(scene_id.is_empty())
		assert_false(scene_ids.has(scene_id), "duplicate scene: " + scene_id)
		scene_ids[scene_id] = true
	var puzzle_ids: Dictionary = {}
	for puzzle in definition.puzzles:
		var puzzle_id := str(puzzle.get("id", ""))
		assert_false(puzzle_ids.has(puzzle_id), "duplicate puzzle: " + puzzle_id)
		puzzle_ids[puzzle_id] = true
		assert_true(scene_ids.has(str(puzzle.get("scene", ""))), "missing scene for " + puzzle_id)
	var dossier := Archive.get_dossier("dossier_wudu")
	assert_not_null(dossier)
	for puzzle in definition.puzzles:
		var card_id := str(puzzle.get("card", ""))
		if card_id.is_empty():
			continue
		var card := Archive.get_card(card_id)
		assert_not_null(card, "missing card " + card_id)
		assert_true(dossier.evidence.has(card), "card not in dossier: " + card_id)
	assert_eq(Chapter.required_cards().size(), 7)
	assert_eq(Chapter.required_cards().size(), dossier.evidence.size())


func test_unlock_graph_follows_puzzles() -> void:
	assert_true(Chapter.scene_unlocked("alley"))
	assert_false(Chapter.scene_unlocked("attic"))
	Chapter.mark_done("P0")
	assert_true(Chapter.scene_unlocked("attic"))
	assert_false(Chapter.scene_unlocked("society"))
	Chapter.mark_done("P1")
	Chapter.mark_done("P2")
	assert_false(Chapter.scene_unlocked("society"))
	Chapter.mark_done("P3")
	assert_true(Chapter.scene_unlocked("society"))
	Chapter.mark_done("P4")
	assert_true(Chapter.scene_unlocked("warehouse"))
	Chapter.mark_done("P5")
	assert_true(Chapter.scene_unlocked("deck"))
	Chapter.mark_done("P6")
	assert_true(Chapter.scene_unlocked("cabin"))
	Chapter.mark_done("P7")
	Chapter.mark_done("P8")
	Chapter.mark_done("P9")
	assert_true(Chapter.scene_unlocked("pier"))
	Chapter.mark_done("P10")
	assert_true(Chapter.scene_cleared("deck"))
	assert_true(Chapter.scene_cleared("cabin"))
	assert_true(Chapter.scene_cleared("pier"))


func test_complete_puzzle_collects_card_and_restores_saturation() -> void:
	Palette.set_saturation(0.4)
	Chapter.complete_puzzle("P2")
	assert_true(Chapter.is_done("P2"))
	assert_true(GameState.has_evidence("card_chart_splice"))
	assert_almost_eq(Palette.saturation, 0.46, 0.001)
	var weight_before := GameState.completeness
	Chapter.complete_puzzle("P2")
	assert_eq(GameState.completeness, weight_before)
	Chapter.complete_puzzle("P0")
	assert_true(Chapter.is_done("P0"))
	assert_eq(GameState.collected.size(), 1)


func test_find_all_completes_when_six_items_found() -> void:
	var view: Control = await _field_scene("P1")
	var items: Array = Chapter.puzzle_def("P1")["params"]["items"]
	var flatlay: TextureRect = _find_flatlay(view)
	assert_not_null(flatlay)
	var buttons: Array[Button] = []
	for child in flatlay.get_children():
		if child is Button:
			buttons.append(child)
	assert_eq(buttons.size(), 9)
	var correct: Array[Button] = []
	var correct_items: Array = []
	for i in items.size():
		if bool(items[i].get("ok", false)):
			correct.append(buttons[i])
			correct_items.append(items[i])
	assert_eq(correct.size(), 6)
	for i in correct.size():
		view._on_item_pressed(correct_items[i], correct[i])
	await wait_process_frames(2)
	assert_true(Chapter.is_done("P1"))
	assert_true(GameState.has_evidence("card_telegraph_1855"))


func test_crate_sum_rejects_wrong_weight_then_accepts_72() -> void:
	var view: Control = await _field_scene("P5")
	var crates: Array[Button] = []
	for child in view.get_node("%Board").get_children():
		if child is Button and child.toggle_mode:
			crates.append(child)
	assert_eq(crates.size(), 6)
	for crate in crates:
		if int(crate.get_meta("weight")) in [14, 22, 30]:
			crate.button_pressed = true
	view._submit_crates()
	assert_false(Chapter.is_done("P5"))
	for crate in crates:
		crate.button_pressed = int(crate.get_meta("weight")) in [14, 22, 36]
	view._submit_crates()
	await wait_process_frames(2)
	assert_true(Chapter.is_done("P5"))
	assert_true(GameState.has_evidence("card_ledger_name"))


func test_sequence_and_dial_modes_complete() -> void:
	var cabin: Control = await _field_scene("P8")
	var latches: Array[Button] = []
	for child in cabin.get_node("%Board").get_children():
		if child is Button:
			latches.append(child)
	assert_eq(latches.size(), 3)
	cabin._on_latch_pressed(0, latches[0])
	cabin._on_latch_pressed(2, latches[2])
	cabin._on_latch_pressed(1, latches[1])
	await wait_process_frames(2)
	assert_true(Chapter.is_done("P8"))
	assert_false(Chapter.is_done("P7"))

	var deck: Control = await _field_scene("P7")
	var slider: HSlider = deck.find_children("*", "HSlider", true, false)[0]
	slider.value = 35.0
	var action: Button = deck.get_node("%BtnAction")
	action.pressed.emit()
	await wait_process_frames(2)
	assert_true(Chapter.is_done("P7"))


func test_seat_and_pair_modes_complete() -> void:
	var society: Control = await _field_scene("P4")
	var seat := _find_button(society.get_node("%Board"), "D3")
	assert_not_null(seat)
	society._on_seat_pressed("D3", seat)
	await wait_process_frames(2)
	assert_true(Chapter.is_done("P4"))
	assert_true(GameState.has_evidence("card_rayn_dissent"))

	var deck: Control = await _field_scene("P6")
	var toggles: Array[Button] = []
	for child in deck.get_node("%Board").find_children("*", "Button", true, false):
		if child.toggle_mode:
			toggles.append(child)
	assert_eq(toggles.size(), 4)
	for toggle in toggles:
		var fragment_id := str(toggle.get_meta("fragment_id", ""))
		toggle.button_pressed = fragment_id in ["papyrus", "tablet"]
	deck._on_fragment_toggled(true)
	deck._submit_pair()
	await wait_process_frames(2)
	assert_true(Chapter.is_done("P6"))


func test_wushu_window_and_correct_move() -> void:
	assert_true(Chapter.definition.puzzle_def("P0")["params"]["lanes"] == [0, 2, 1, 0])
	var script := load("res://scripts/ui/wushu.gd")
	assert_true(script.hit_window_contains(800.0, 800.0, 135.0))
	assert_true(script.hit_window_contains(935.0, 800.0, 135.0))
	assert_false(script.hit_window_contains(935.1, 800.0, 135.0))

	GameState.current_puzzle_id = "P0"
	var scene := load("res://scenes/wushu.tscn") as PackedScene
	var alley := scene.instantiate()
	add_child_autofree(alley)
	await wait_process_frames(2)
	alley._on_lane_pressed(0)
	assert_false(Chapter.is_done("P0"))
	alley._show_moves()
	var reverse := _find_button(alley.get_node("%Arena"), "反剪手腕")
	assert_not_null(reverse)
	alley._on_move_pressed("reverse", reverse)
	await wait_process_frames(2)
	assert_true(Chapter.is_done("P0"))


func test_plate_stack_needs_five_plates() -> void:
	GameState.current_puzzle_id = "P10"
	var scene := load("res://scenes/plate_stack.tscn") as PackedScene
	var pier := scene.instantiate()
	add_child_autofree(pier)
	await wait_process_frames(2)
	var plates: Array[PlateToken] = []
	for child in pier.get_node("%Arena").get_children():
		if child is PlateToken:
			plates.append(child)
	assert_eq(plates.size(), 5)
	assert_eq(pier.get_node("%HatReveal").strength, 0.0)
	for plate in plates:
		pier._dock(plate)
	await wait_seconds(0.6)
	assert_eq(pier._docked.size(), 5)
	await wait_seconds(2.0)
	assert_true(Chapter.is_done("P10"))
	assert_true(GameState.has_evidence("card_plate_stack"))


func test_chapter_ready_requires_seven_cards() -> void:
	var cards := Chapter.required_cards()
	assert_eq(cards.size(), 7)
	for i in 6:
		GameState.collect_evidence(cards[i], 10)
	assert_false(Chapter.chapter_ready())
	GameState.collect_evidence(cards[6], 10)
	assert_true(Chapter.chapter_ready())


func _find_flatlay(root: Node) -> TextureRect:
	for child in root.get_node("%Board").get_children():
		if child is TextureRect:
			return child
	return null


func _find_button(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node
	return null
