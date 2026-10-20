extends Control
## 校图台：拖动描图纸，把中心十字对准底图上的脉动铜环。

const DOSSIER_ID := "dossier_wudu"
const CARD_ID := "card_chart_splice"
const SCENE_PATH := "res://scenes/scene_view.tscn"
const SNAP_DISTANCE := 64.0

@onready var trace_sheet: TraceSheet = %TraceSheet
@onready var target: TargetReticle = %Target
@onready var offset_label: Label = %OffsetLabel
@onready var hint_label: Label = %HintLabel
@onready var back_button: Button = %BtnBack
@onready var result: Control = %Result
@onready var result_title: Label = %ResultTitle
@onready var result_meta: Label = %ResultMeta
@onready var result_body: RichTextLabel = %ResultBody
@onready var return_button: Button = %BtnReturn

var _solved := false


func _ready() -> void:
	trace_sheet.drag_bounds = Rect2(20.0, 200.0, 1040.0, 1360.0)
	trace_sheet.moved.connect(_on_sheet_moved)
	trace_sheet.released.connect(_on_sheet_released)
	back_button.pressed.connect(_return_to_scene)
	return_button.pressed.connect(_return_to_scene)
	_on_sheet_moved(trace_sheet.center_global())
	_apply_debug_args()


static func is_within_snap(distance: float) -> bool:
	return distance <= SNAP_DISTANCE


func _target_center() -> Vector2:
	return target.global_position + target.size * 0.5


func _sheet_distance() -> float:
	return trace_sheet.center_global().distance_to(_target_center())


func _on_sheet_moved(center: Vector2) -> void:
	var distance := center.distance_to(_target_center())
	offset_label.text = "%d px" % int(distance)
	var aligned := is_within_snap(distance)
	offset_label.modulate = Color(0.62, 0.86, 0.58) if aligned else Color(0.95, 0.78, 0.46)
	hint_label.text = "松手即校合" if aligned else "拖动描图纸，让纸上的十字对准脉动铜环"


func _on_sheet_released(_center: Vector2) -> void:
	if _solved:
		return
	if is_within_snap(_sheet_distance()):
		_solve()


func _solve() -> void:
	if _solved:
		return
	_solved = true
	trace_sheet.set_interactive(false)
	var tween := create_tween()
	tween.tween_property(trace_sheet, "global_position", _target_center() - trace_sheet.size * 0.5, 0.28).set_trans(Tween.TRANS_SINE)
	await tween.finished
	_collect()
	_show_result()


func _collect() -> void:
	var card := Archive.get_card(CARD_ID)
	GameState.collect_evidence(CARD_ID, card.weight if card != null else 10)
	Palette.restore_with_stamp(0.12)
	GameState.save_to()


func _show_result() -> void:
	var card := Archive.get_card(CARD_ID)
	if card != null:
		result_title.text = card.title
		result_body.text = card.body + "\n\n描图纸上的罗盘线压住底图的旧针脚，四份残片的经线终于落在同一处。那个空白岛位，被四张图刻意留空。"
	var dossier := Archive.get_dossier(DOSSIER_ID)
	var got := 0
	if dossier != null:
		for c in dossier.evidence:
			if GameState.has_evidence(c.id):
				got += 1
		result_meta.text = "档案 WG-1865 ｜ 证据 %02d / %02d ｜ 校合完成" % [got, dossier.evidence.size()]
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
