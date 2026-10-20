class_name ChapterDef
extends Resource
## 一章 = 一组可进入的现场 + 一组谜题。内容全部来自 .tres，代码只解释 kind。

@export var id: String = ""
@export var title: String = ""
@export var subtitle: String = ""
@export var scenes: Array = []
@export var puzzles: Array = []


func scene_def(scene_id: String) -> Dictionary:
	for scene in scenes:
		if str(scene.get("id", "")) == scene_id:
			return scene
	return {}


func puzzle_def(puzzle_id: String) -> Dictionary:
	for puzzle in puzzles:
		if str(puzzle.get("id", "")) == puzzle_id:
			return puzzle
	return {}


func puzzles_in(scene_id: String) -> Array:
	var result: Array = []
	for puzzle in puzzles:
		if str(puzzle.get("scene", "")) == scene_id:
			result.append(puzzle)
	return result
