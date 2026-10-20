extends Control
## 校图台：拖动描图纸，把纸上的对位十字压到脉动铜环上。参数来自章节目录。

const DEFAULT_SNAP_DISTANCE := 64.0
const SCENE_PATH := "res://scenes/scene_view.tscn"

@onready var background: TextureRect = $Background
@onready var paper: TextureRect = $TraceSheet/Paper
@onready var trace_sheet: TraceSheet = %TraceSheet
@onready var crosshair: Crosshair = $TraceSheet/Crosshair
@onready var target: TargetReticle = %Target
@onready var offset_label: Label = %OffsetLabel
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
var _snap_distance := DEFAULT_SNAP_DISTANCE
var _solved := false


func _ready() -> void:
	Audio.set_ambience("amb_field")
	_puzzle = Chapter.puzzle_def(GameState.current_puzzle_id)
	if _puzzle.is_empty():
		_puzzle = Chapter.puzzle_def("P2")
	_params = _puzzle.get("params", {})
	_apply_params()
	trace_sheet.drag_bounds = Rect2(20.0, 200.0, 1040.0, 1360.0)
	trace_sheet.moved.connect(_on_sheet_moved)
	trace_sheet.released.connect(_on_sheet_released)
	back_button.pressed.connect(_return_to_scene)
	return_button.pressed.connect(_return_to_scene)
	_on_sheet_moved(trace_sheet.center_global())
	_apply_debug_args()


func _apply_params() -> void:
	var base_path := str(_params.get("base", "res://assets/ui/chart_base.jpg"))
	var trace_path := str(_params.get("trace", "res://assets/ui/chart_trace.jpg"))
	var base_texture := load(base_path) as Texture2D
	var trace_texture := load(trace_path) as Texture2D
	if base_texture != null:
		background.texture = base_texture
	if trace_texture != null:
		paper.texture = trace_texture

	var target_pos: Vector2 = _params.get("target", Vector2(700, 780))
	target.position = target_pos - target.size * 0.5
	var start: Vector2 = _params.get("start", Vector2(30, 440))
	trace_sheet.position = start
	var focus: Vector2 = _params.get("focus", Vector2(0.5, 0.5))
	trace_sheet.focus_ratio = focus
	crosshair.set_focus_ratio(focus)
	_snap_distance = float(_params.get("tolerance", DEFAULT_SNAP_DISTANCE))

	ribbon_label.text = tr("序卷 · 雾都    ｜    校图台    ｜    %s") % tr(str(_puzzle.get("title", "航记对位")))
	hint_label.text = str(_params.get("prompt", "拖动描图纸，让纸上的十字对准脉动铜环"))
	result_eyebrow.text = str(_params.get("eyebrow", "校合 · ALIGNED"))
	var metric_note := $HintPanel/Box/MetricRow/MetricNote as Label
	metric_note.text = tr("≤ %d px 松手即校合") % int(_snap_distance)


static func is_within_snap(distance: float, tolerance: float = DEFAULT_SNAP_DISTANCE) -> bool:
	return distance <= tolerance


func _target_center() -> Vector2:
	return target.global_position + target.size * 0.5


func _sheet_distance() -> float:
	return trace_sheet.center_global().distance_to(_target_center())


func _on_sheet_moved(center: Vector2) -> void:
	var distance := center.distance_to(_target_center())
	offset_label.text = "%d px" % int(distance)
	var aligned := is_within_snap(distance, _snap_distance)
	offset_label.modulate = Color(0.62, 0.86, 0.58) if aligned else Color(0.95, 0.78, 0.46)
	hint_label.text = "松手即校合" if aligned else str(_params.get("prompt", "拖动描图纸，让纸上的十字对准脉动铜环"))


func _on_sheet_released(_center: Vector2) -> void:
	if _solved:
		return
	if is_within_snap(_sheet_distance(), _snap_distance):
		_solve()


func _solve() -> void:
	if _solved:
		return
	_solved = true
	Audio.play("align_snap", -3.0)
	trace_sheet.set_interactive(false)
	var tween := create_tween()
	tween.tween_property(trace_sheet, "global_position", _target_center() - trace_sheet.size * trace_sheet.focus_ratio, 0.28).set_trans(Tween.TRANS_SINE)
	await tween.finished
	_complete()
	_show_result()


func _complete() -> void:
	var puzzle_id := str(_puzzle.get("id", ""))
	if not puzzle_id.is_empty():
		Chapter.complete_puzzle(puzzle_id)
	GameState.save_to()


func _show_result() -> void:
	var card := Archive.get_card(str(_puzzle.get("card", "")))
	var body := str(_params.get("result", ""))
	if card != null:
		result_title.text = tr(card.title)
		result_body.text = "%s\n\n%s" % [tr(card.body), tr(body)]
	else:
		result_title.text = tr(str(_params.get("result_title", _puzzle.get("title", "校合完成"))))
		result_body.text = tr(body)
	var dossier := Archive.get_dossier(GameState.current_dossier_id)
	var got := 0
	if dossier != null:
		for c in dossier.evidence:
			if GameState.has_evidence(c.id):
				got += 1
		result_meta.text = tr("档案 WG-1865 ｜ 证据 %02d / %02d ｜ 校合完成") % [got, dossier.evidence.size()]
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
		if arg == "--demo-solved":
			_solve.call_deferred()
