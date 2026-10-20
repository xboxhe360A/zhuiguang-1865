extends Control
## Step 2 系统验证屏：档案库 / 证据收集 / 饱和度 / 存档，后续由档案桌替换。

const DOSSIER_ID := "dossier_wudu"

@onready var status: Label = %Status
@onready var completeness_label: Label = %CompletenessLabel
@onready var completeness_bar: ProgressBar = %CompletenessBar
@onready var saturation_slider: HSlider = %SaturationSlider
@onready var saturation_value: Label = %SaturationValue
@onready var toast: Label = %Toast
@onready var toast_timer: Timer = %ToastTimer


func _ready() -> void:
	GameState.completeness_changed.connect(_on_state_changed)
	GameState.evidence_collected.connect(_on_evidence_collected)
	GameState.verdict_recorded.connect(_on_verdict_recorded)
	Palette.saturation_changed.connect(_on_saturation_changed)

	%BtnCollect.pressed.connect(_on_collect_pressed)
	%BtnStamp.pressed.connect(_on_stamp_pressed)
	%BtnSave.pressed.connect(_on_save_pressed)
	%BtnLoad.pressed.connect(_on_load_pressed)
	%BtnReset.pressed.connect(_on_reset_pressed)
	%BtnTrue.pressed.connect(_record.bind("true"))
	%BtnFalse.pressed.connect(_record.bind("false"))
	%BtnDoubt.pressed.connect(_record.bind("doubt"))
	%SaturationSlider.value_changed.connect(_on_slider_changed)
	toast_timer.timeout.connect(func() -> void: toast.text = "")

	saturation_slider.value = Palette.saturation
	_refresh()
	_apply_debug_args()


func _apply_debug_args() -> void:
	if not OS.is_debug_build():
		return
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo-collect":
			_on_collect_pressed()
		elif arg.begins_with("--demo-sat="):
			Palette.set_saturation(arg.trim_prefix("--demo-sat=").to_float())
		elif arg.begins_with("--demo-verdict="):
			_record(arg.trim_prefix("--demo-verdict="))


func _on_collect_pressed() -> void:
	for card in Archive.cards_for(DOSSIER_ID):
		GameState.collect_evidence(card.id, card.weight)
	_toast("本档证据已入档")


func _on_stamp_pressed() -> void:
	Palette.restore_with_stamp(0.1)
	_toast("印章显色 +0.10")


func _on_save_pressed() -> void:
	var err := GameState.save_to()
	_toast("已存档" if err == OK else "存档失败：%s" % error_string(err))


func _on_load_pressed() -> void:
	var err := GameState.load_from()
	_toast("已读档" if err == OK else "读档失败：%s" % error_string(err))
	_refresh()


func _on_reset_pressed() -> void:
	GameState.reset_run()
	Palette.reset()
	_toast("已重置")


func _record(verdict: String) -> void:
	GameState.record_verdict(DOSSIER_ID, verdict)
	_toast("已裁定：%s" % _verdict_text(verdict))


func _on_slider_changed(value: float) -> void:
	Palette.set_saturation(value)


func _on_state_changed(_value: int) -> void:
	_refresh()


func _on_evidence_collected(_card_id: String) -> void:
	_refresh()


func _on_verdict_recorded(_dossier_id: String, _verdict: String) -> void:
	_refresh()


func _on_saturation_changed(value: float) -> void:
	saturation_slider.set_value_no_signal(value)
	saturation_value.text = "%.2f" % value
	_refresh()


func _refresh() -> void:
	var dossier := Archive.get_dossier(DOSSIER_ID)
	var total := 0
	var got := 0
	for card in Archive.cards_for(DOSSIER_ID):
		total += 1
		if GameState.has_evidence(card.id):
			got += 1
	var verdict := str(GameState.verdicts.get(DOSSIER_ID, ""))
	status.text = "《%s》｜ 证据 %d/%d ｜ 三声裁定：%s" % [
		dossier.title if dossier != null else "档案缺失",
		got,
		total,
		_verdict_text(verdict) if not verdict.is_empty() else "未裁定",
	]
	completeness_label.text = "档案完整度 %d / 100" % GameState.completeness
	completeness_bar.value = GameState.completeness
	saturation_value.text = "%.2f" % Palette.saturation


func _verdict_text(verdict: String) -> String:
	match verdict:
		"true":
			return "存真"
		"false":
			return "证伪"
		"doubt":
			return "存疑"
		_:
			return "未裁定"


func _toast(message: String) -> void:
	toast.text = message
	toast_timer.start()
