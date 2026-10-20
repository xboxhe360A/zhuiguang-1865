extends GutTest


func test_wudu_dossier_is_registered() -> void:
	var dossier := Archive.get_dossier("dossier_wudu")
	assert_not_null(dossier)
	assert_eq(dossier.title, "雾都 · 格雷遗物")
	assert_eq(dossier.volume, "unfiled")


func test_wudu_has_seven_cards_and_eleven_puzzles() -> void:
	var cards := Archive.cards_for("dossier_wudu")
	assert_eq(cards.size(), 7)
	var total_weight := 0
	for card in cards:
		total_weight += card.weight
	assert_eq(total_weight, 70)
	assert_eq(Archive.get_dossier("dossier_wudu").puzzle_ids.size(), 11)


func test_cards_are_indexed_by_id() -> void:
	var dissent := Archive.get_card("card_rayn_dissent")
	assert_not_null(dissent)
	assert_true(dissent.is_dissent)
	assert_eq(Archive.get_card("card_missing"), null)


func test_unknown_dossier_returns_empty_cards() -> void:
	assert_eq(Archive.cards_for("dossier_missing").size(), 0)


func test_cards_have_unique_non_empty_ids() -> void:
	var seen: Dictionary = {}
	for card in Archive.cards.values():
		assert_false(card.id.is_empty(), "card id must not be empty")
		assert_false(seen.has(card.id), "duplicate card id: " + card.id)
		seen[card.id] = true
