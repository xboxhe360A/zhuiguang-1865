extends Control
## 暗房显影：按住底片来回擦拭，乳剂下的影像与背印一起浮出。参数来自章节目录。

const SCENE_PATH := "res://scenes/scene_view.tscn"

@onready var plate: DevelopingPlate = %Plate
@onready var surface: DevelopSurface = %DevelopSurface
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var percent_label: Label = %PercentLabel
@onready var hint_label: Label = %HintLabel
@onready var ribbon_label: Label = %RibbonLabel
@onready var result_eyebrow: Label = %ResultEyebrow
@onready var back_button: Button = %BtnBack
@onready var result: Control = %Result
@onready var result_title: Label = %ResultTitle
@onready var result_meta: Label = %ResultMeta
@onready var result_body: RichTextLabel = %ResultBody
@onready var return_button: Button = %BtnReturn

var _puzzle: Dictionary = {}
var _params: Dictionary = {}
var _progress := 0.0
var _finished := false


func _ready() -> void:
	_puzzle = Chapter.puzzle_def(GameState.current_puzzle_id)
	if _puzzle.is_empty():
		_puzzle = Chapter.puzzle_def("P3")
	_params = _puzzle.get("params", {})
	_apply_params()
	surface.rubbed.connect(_on_rubbed)
	back_button.pressed.connect(_return_to_scene)
	return_button.pressed.connect(_return_to_scene)
	set_progress(0.0)
	_apply_debug_args()


func _apply_params() -> void:
	var plate_path := str(_params.get("plate", "res://assets/ui/plate_negative.jpg"))
	var texture := load(plate_path) as Texture2D
	if texture != null:
		plate.texture = texture
	ribbon_label.text = "序卷 · 雾都    ｜    暗房    ｜    %s" % str(_puzzle.get("title", "湿版显影"))
	result_eyebrow.text = str(_params.get("eyebrow", "显影 · DEVELOPED"))
	hint_label.text = str(_params.get("prompt", "按住底片来回擦拭，让乳剂下的影像浮出"))


func get_progress() -> float:
	return _progress


func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	plate.set_progress(_progress)
	progress_bar.value = _progress
	percent_label.text = "%d%%" % int(round(_progress * 100.0))
	if _progress >= 1.0:
		hint_label.text = "影像已定影"
	elif _progress > 0.0:
		hint_label.text = "继续擦拭 · 乳剂正在起影"


func add_progress(amount: float) -> void:
	if _finished:
		return
	set_progress(_progress + amount)
	if _progress >= 1.0:
		_finish()


func _on_rubbed(amount: float) -> void:
	add_progress(amount)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	surface.set_interactive(false)
	var puzzle_id := str(_puzzle.get("id", ""))
	if not puzzle_id.is_empty():
		Chapter.complete_puzzle(puzzle_id)
	GameState.save_to()
	await get_tree().create_timer(0.45).timeout
	_show_result()


func _show_result() -> void:
	var card := Archive.get_card(str(_puzzle.get("card", "")))
	var extra := str(_params.get("result", ""))
	if card != null:
		result_title.text = card.title
		result_body.text = "%s\n\n%s" % [card.body, extra]
	else:
		result_title.text = str(_params.get("result_title", _puzzle.get("title", "显影完成")))
		result_body.text = extra
	var dossier := Archive.get_dossier(GameState.current_dossier_id)
	var got := 0
	if dossier != null:
		for c in dossier.evidence:
			if GameState.has_evidence(c.id):
				got += 1
		result_meta.text = "档案 WG-1865 ｜ 证据 %02d / %02d ｜ 显影完成" % [got, dossier.evidence.size()]
	result.visible = true
	result.modulate.a = 0.0
	create_tween().tween_property(result, "modulate:a", 1.0, 0.25)


func _return_to_scene() -> void:
	GameState.save_to()
	get_tree().change_scene_to_file(SCENE_PATH)


func _apply_debug_args() -> void:
	if not OS.is_debug_build():
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo-progress="):
			set_progress(float(arg.trim_prefix("--demo-progress=")))
		elif arg == "--demo-solved":
			set_progress(1.0)
			_finish.call_deferred()
