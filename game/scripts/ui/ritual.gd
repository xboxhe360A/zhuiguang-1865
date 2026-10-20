extends Control
## 三声裁定：存真 / 证伪 / 存疑。雾都卷的定论是「存疑」——档案从不替历史合上封皮。

const DOSSIER_ID := "dossier_wudu"
const DESK_PATH := "res://scenes/archive_desk.tscn"
const CANONICAL_VERDICT := "doubt"

@onready var summary_label: Label = %SummaryLabel
@onready var hint_label: Label = %HintLabel
@onready var back_button: Button = %BtnBack
@onready var toast: Label = %Toast
@onready var toast_timer: Timer = %ToastTimer
@onready var seal: Control = %Seal
@onready var seal_circle: Control = %SealCircle
@onready var seal_title: Label = %SealTitle
@onready var seal_body: Label = %SealBody
@onready var desk_button: Button = %BtnDesk

var _choice_buttons: Array[Button] = []
var _sealed := false


func _ready() -> void:
	_choice_buttons = [%BtnTrue, %BtnFalse, %BtnDoubt]
	for i in _choice_buttons.size():
		_choice_buttons[i].pressed.connect(_on_choice.bind(i))
	back_button.pressed.connect(_return_to_desk)
	desk_button.pressed.connect(_return_to_desk)
	toast_timer.timeout.connect(func() -> void: toast.text = "")
	_refresh_summary()
	_apply_debug_args()


static func verdict_for(index: int) -> String:
	match index:
		0:
			return "true"
		1:
			return "false"
		2:
			return "doubt"
		_:
			return ""


static func is_canonical(index: int) -> bool:
	return verdict_for(index) == CANONICAL_VERDICT


func _refresh_summary() -> void:
	var dossier := Archive.get_dossier(DOSSIER_ID)
	var got := 0
	if dossier != null:
		for card in dossier.evidence:
			if GameState.has_evidence(card.id):
				got += 1
	summary_label.text = "已归档证据 %d / %d ｜ 现下饱和 %d%% ｜ 三册未封" % [
		got,
		dossier.evidence.size() if dossier != null else 0,
		int(round(Palette.saturation * 100.0)),
	]
	var existing := str(GameState.verdicts.get(DOSSIER_ID, ""))
	if not existing.is_empty():
		hint_label.text = "本卷已经裁定：%s" % _verdict_text(existing)


func _on_choice(index: int) -> void:
	if _sealed:
		return
	var verdict := verdict_for(index)
	if verdict.is_empty():
		return
	if verdict == CANONICAL_VERDICT:
		_seal()
	else:
		_reject(_choice_buttons[index])


func _reject(button: Button) -> void:
	Palette.add_saturation(-0.1)
	toast.text = "这一声压不住纸页。墨迹褪去了一点。"
	toast_timer.start()
	hint_label.text = "雷恩的异议仍在册：两套坐标都自洽，惟原图不见。"
	var base := button.position
	var tween := create_tween()
	tween.tween_property(button, "position", base + Vector2(14, 0), 0.05)
	tween.tween_property(button, "position", base - Vector2(14, 0), 0.05)
	tween.tween_property(button, "position", base, 0.05)


func _seal() -> void:
	if _sealed:
		return
	_sealed = true
	for button in _choice_buttons:
		button.disabled = true
	GameState.record_verdict(DOSSIER_ID, CANONICAL_VERDICT)
	Palette.add_saturation(0.1)
	GameState.save_to()
	seal_title.text = "已封存 · 记忆册"
	seal_body.text = "本卷不判真伪。两种可能一并收入记忆册，留待后来者翻到这一页。"
	seal.visible = true
	seal.modulate.a = 0.0
	seal_circle.pivot_offset = seal_circle.size * 0.5
	seal_circle.scale = Vector2(1.4, 1.4)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(seal, "modulate:a", 1.0, 0.28)
	tween.tween_property(seal_circle, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _return_to_desk() -> void:
	GameState.save_to()
	get_tree().change_scene_to_file(DESK_PATH)


func _verdict_text(verdict: String) -> String:
	match verdict:
		"true":
			return "存真 · 存在册"
		"false":
			return "证伪 · 编年册"
		"doubt":
			return "存疑 · 记忆册"
		_:
			return "未裁定"


func _apply_debug_args() -> void:
	if not OS.is_debug_build():
		return
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo-solved":
			_seal.call_deferred()
		elif arg == "--demo-wrong":
			_on_choice.call_deferred(0)
