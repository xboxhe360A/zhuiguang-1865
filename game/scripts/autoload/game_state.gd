extends Node
## 全局档案状态：证据收集、三册裁定、完整度。存档为 JSON，正式数据由 Archive 载入 .tres。

signal evidence_collected(card_id: String)
signal verdict_recorded(dossier_id: String, verdict: String)
signal completeness_changed(value: int)

const VOLUMES: Array[String] = ["existence", "annal", "memory"]
const VERDICTS: Array[String] = ["true", "false", "doubt"]

var current_dossier_id: String = ""
var current_scene_id: String = ""
var current_puzzle_id: String = ""
var collected: Dictionary = {}
var verdicts: Dictionary = {}
var puzzles_done: Dictionary = {}
var completeness: int = 0


func reset_run() -> void:
	current_dossier_id = ""
	current_scene_id = ""
	current_puzzle_id = ""
	collected.clear()
	verdicts.clear()
	puzzles_done.clear()
	completeness = 0
	completeness_changed.emit(completeness)


func collect_evidence(card_id: String, weight: int = 1) -> void:
	if card_id.is_empty() or collected.has(card_id):
		return
	collected[card_id] = true
	completeness = clampi(completeness + weight, 0, 100)
	evidence_collected.emit(card_id)
	completeness_changed.emit(completeness)


func has_evidence(card_id: String) -> bool:
	return collected.has(card_id)


func record_verdict(dossier_id: String, verdict: String) -> void:
	if dossier_id.is_empty() or verdict not in VERDICTS:
		push_error("invalid verdict: %s -> %s" % [dossier_id, verdict])
		return
	verdicts[dossier_id] = verdict
	verdict_recorded.emit(dossier_id, verdict)


func save_to(path: String = "user://save.json") -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var data := {
		"current_dossier_id": current_dossier_id,
		"current_scene_id": current_scene_id,
		"collected": collected.keys(),
		"verdicts": verdicts,
		"puzzles_done": puzzles_done,
		"completeness": completeness,
		"saturation": Palette.saturation,
	}
	file.store_string(JSON.stringify(data, "\t"))
	return OK


func load_from(path: String = "user://save.json") -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return ERR_PARSE_ERROR
	var data: Dictionary = parsed
	current_dossier_id = str(data.get("current_dossier_id", ""))
	current_scene_id = str(data.get("current_scene_id", ""))
	collected.clear()
	for id in data.get("collected", []):
		collected[str(id)] = true
	verdicts = data.get("verdicts", {})
	puzzles_done = data.get("puzzles_done", {})
	completeness = int(data.get("completeness", 0))
	Palette.set_saturation(float(data.get("saturation", 0.35)))
	completeness_changed.emit(completeness)
	return OK
