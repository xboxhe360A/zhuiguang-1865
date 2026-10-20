extends Node
## 章节进度：现场解锁、谜题完成、证据卡发放。所有内容取自 ChapterDef。

const DEF_PATH := "res://data/chapters/wudu.tres"
const DESK_PATH := "res://scenes/archive_desk.tscn"

var definition: ChapterDef


func _ready() -> void:
	definition = load(DEF_PATH) as ChapterDef
	if definition == null:
		push_error("chapter load failed: " + DEF_PATH)


func scene_def(scene_id: String) -> Dictionary:
	if definition == null:
		return {}
	return definition.scene_def(scene_id)


func puzzle_def(puzzle_id: String) -> Dictionary:
	if definition == null:
		return {}
	return definition.puzzle_def(puzzle_id)


func puzzles_in(scene_id: String) -> Array:
	if definition == null:
		return []
	return definition.puzzles_in(scene_id)


func is_done(puzzle_id: String) -> bool:
	return GameState.puzzles_done.has(puzzle_id)


func mark_done(puzzle_id: String) -> void:
	if not puzzle_id.is_empty():
		GameState.puzzles_done[puzzle_id] = true


func scene_completed(scene_id: String) -> int:
	var count := 0
	for puzzle in puzzles_in(scene_id):
		if is_done(str(puzzle.get("id", ""))):
			count += 1
	return count


func scene_cleared(scene_id: String) -> bool:
	var puzzles := puzzles_in(scene_id)
	if puzzles.is_empty():
		return false
	return scene_completed(scene_id) == puzzles.size()


func scene_unlocked(scene_id: String) -> bool:
	var scene := scene_def(scene_id)
	for required in scene.get("requires", []):
		if not is_done(str(required)):
			return false
	return true


func required_cards() -> Array[String]:
	var result: Array[String] = []
	var dossier := Archive.get_dossier(GameState.current_dossier_id if not GameState.current_dossier_id.is_empty() else "dossier_wudu")
	if dossier == null:
		return result
	for card in dossier.evidence:
		result.append(card.id)
	return result


func missing_cards() -> Array[String]:
	var result: Array[String] = []
	for card_id in required_cards():
		if not GameState.has_evidence(card_id):
			result.append(card_id)
	return result


func chapter_ready() -> bool:
	return missing_cards().is_empty() and not required_cards().is_empty()


func complete_puzzle(puzzle_id: String) -> void:
	var puzzle := puzzle_def(puzzle_id)
	if puzzle.is_empty() or is_done(puzzle_id):
		return
	mark_done(puzzle_id)
	var card_id := str(puzzle.get("card", ""))
	if not card_id.is_empty() and not GameState.has_evidence(card_id):
		var card := Archive.get_card(card_id)
		GameState.collect_evidence(card_id, card.weight if card != null else int(puzzle.get("weight", 10)))
	Palette.restore_with_stamp(float(puzzle.get("restore", 0.08)))
	GameState.save_to()
