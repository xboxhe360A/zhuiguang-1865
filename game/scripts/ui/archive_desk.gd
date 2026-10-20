extends Control
## 1905 档案桌 hub：章节入口、读档与进度概览。

const DOSSIER_ID := "dossier_wudu"
const SCENE_PATH := "res://scenes/scene_view.tscn"
const SAVE_PATH := "user://save.json"

@onready var progress_label: Label = %ProgressLabel
@onready var enter_button: Button = %BtnEnter
@onready var load_button: Button = %BtnLoad
@onready var toast: Label = %Toast
@onready var toast_timer: Timer = %ToastTimer


func _ready() -> void:
	enter_button.pressed.connect(_on_enter_pressed)
	load_button.pressed.connect(_on_load_pressed)
	toast_timer.timeout.connect(func() -> void: toast.text = "")
	if GameState.collected.is_empty() and GameState.verdicts.is_empty() and FileAccess.file_exists(SAVE_PATH):
		GameState.load_from()
	_refresh()
	if OS.is_debug_build() and "--demo-enter" in OS.get_cmdline_user_args():
		_on_enter_pressed.call_deferred()


func _on_enter_pressed() -> void:
	GameState.current_dossier_id = DOSSIER_ID
	get_tree().change_scene_to_file(SCENE_PATH)


func _on_load_pressed() -> void:
	var err := GameState.load_from()
	_refresh()
	toast.text = "已读档" if err == OK else "读档失败：%s" % error_string(err)
	toast_timer.start()


func _refresh() -> void:
	var dossier := Archive.get_dossier(DOSSIER_ID)
	if dossier == null:
		progress_label.text = "档案缺失"
		enter_button.disabled = true
		return

	var got := 0
	for card in dossier.evidence:
		if GameState.has_evidence(card.id):
			got += 1
	var verdict := str(GameState.verdicts.get(DOSSIER_ID, ""))
	progress_label.text = "证据 %d / %d ｜ 三声裁定：%s" % [
		got,
		dossier.evidence.size(),
		_verdict_text(verdict) if not verdict.is_empty() else "未裁定",
	]
	enter_button.text = "继续卷宗" if got > 0 or not verdict.is_empty() else "打开卷宗"
	load_button.disabled = not FileAccess.file_exists(SAVE_PATH)


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
