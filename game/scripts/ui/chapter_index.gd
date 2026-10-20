extends Control
## 卷宗目录：1905 档案层里的现场索引。锁、进度、裁定入口都在这一页。

const DOSSIER_ID := "dossier_wudu"
const SCENE_PATH := "res://scenes/scene_view.tscn"
const RITUAL_PATH := "res://scenes/ritual.tscn"
const DESK_PATH := "res://scenes/archive_desk.tscn"

@onready var progress_label: Label = %ProgressLabel
@onready var scene_list: VBoxContainer = %SceneList
@onready var desk_button: Button = %BtnDesk
@onready var ritual_button: Button = %BtnRitual
@onready var continue_button: Button = %BtnContinue
@onready var toast: Label = %Toast
@onready var toast_timer: Timer = %ToastTimer


func _ready() -> void:
	Audio.set_ambience("amb_archive")
	GameState.current_dossier_id = DOSSIER_ID
	desk_button.pressed.connect(_go_desk)
	ritual_button.pressed.connect(_open_ritual)
	continue_button.pressed.connect(_continue)
	toast_timer.timeout.connect(func() -> void: toast.text = "")
	_build_rows()
	_refresh()
	_apply_debug_args()


func _build_rows() -> void:
	for child in scene_list.get_children():
		scene_list.remove_child(child)
		child.queue_free()
	if Chapter.definition == null:
		return
	for scene in Chapter.definition.scenes:
		scene_list.add_child(_make_row(scene))


func _make_row(scene: Dictionary) -> Button:
	var scene_id := str(scene.get("id", ""))
	var unlocked := Chapter.scene_unlocked(scene_id)
	var puzzles := Chapter.puzzles_in(scene_id)
	var done := Chapter.scene_completed(scene_id)
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, 136)
	row.focus_mode = Control.FOCUS_NONE
	row.disabled = not unlocked
	row.add_theme_stylebox_override("normal", _row_style(false, unlocked))
	row.add_theme_stylebox_override("hover", _row_style(true, unlocked))
	row.add_theme_stylebox_override("pressed", _row_style(true, unlocked))
	row.add_theme_stylebox_override("disabled", _row_style(false, false))
	if unlocked:
		row.pressed.connect(_open_scene.bind(scene_id))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	row.add_child(margin)

	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 24)
	margin.add_child(line)

	var numeral := Label.new()
	numeral.text = str(scene.get("index", "·"))
	numeral.custom_minimum_size = Vector2(72, 0)
	numeral.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	numeral.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	numeral.add_theme_font_size_override("font_size", 44)
	numeral.add_theme_color_override("font_color", Color(0.85098, 0.741176, 0.454902, 1) if unlocked else Color(0.45, 0.5, 0.5, 1))
	numeral.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(numeral)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.add_theme_constant_override("separation", 2)
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(text_box)

	var name_label := Label.new()
	name_label.text = str(scene.get("title", ""))
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", Color(0.909804, 0.827451, 0.627451, 1) if unlocked else Color(0.55, 0.58, 0.56, 1))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(name_label)

	var subtitle := Label.new()
	subtitle.text = str(scene.get("subtitle", ""))
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.67, 0.65, 1) if unlocked else Color(0.42, 0.46, 0.45, 1))
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(subtitle)

	var status := Label.new()
	status.text = _status_text(scene_id, unlocked, done, puzzles.size())
	status.add_theme_font_size_override("font_size", 21)
	status.add_theme_color_override("font_color", _status_color(unlocked, done, puzzles.size()))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(status)

	var arrow := Label.new()
	arrow.text = "›"
	arrow.custom_minimum_size = Vector2(44, 0)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.add_theme_font_size_override("font_size", 44)
	arrow.add_theme_color_override("font_color", Color(0.85098, 0.741176, 0.454902, 1) if unlocked else Color(0.5, 0.52, 0.5, 0.5))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(arrow)
	return row


func _row_style(hover: bool, unlocked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.09, 0.9) if unlocked else Color(0.025, 0.04, 0.045, 0.75)
	if hover and unlocked:
		style.bg_color = Color(0.08, 0.14, 0.15, 0.95)
	style.border_width_left = 3
	style.border_color = Color(0.85098, 0.741176, 0.454902, 0.75 if unlocked else 0.22)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 5)
	return style


func _status_text(scene_id: String, unlocked: bool, done: int, total: int) -> String:
	if not unlocked:
		var missing: Array[String] = []
		for required in Chapter.scene_def(scene_id).get("requires", []):
			var puzzle := Chapter.puzzle_def(str(required))
			missing.append(tr(str(puzzle.get("title", required))))
		return tr("未开启 · 需完成「%s」") % tr("、").join(missing)
	if done == total:
		return tr("已查清 · %d / %d") % [done, total]
	return tr("待查 · %d / %d") % [done, total]


func _status_color(unlocked: bool, done: int, total: int) -> Color:
	if not unlocked:
		return Color(0.5, 0.52, 0.5, 1)
	if done == total:
		return Color(0.62, 0.86, 0.58, 1)
	return Color(0.85098, 0.741176, 0.454902, 1)


func _refresh() -> void:
	var dossier := Archive.get_dossier(DOSSIER_ID)
	var got := 0
	if dossier != null:
		for card in dossier.evidence:
			if GameState.has_evidence(card.id):
				got += 1
		progress_label.text = tr("证据 %d / %d") % [got, dossier.evidence.size()]
	ritual_button.visible = Chapter.chapter_ready() and str(GameState.verdicts.get(DOSSIER_ID, "")).is_empty()
	continue_button.disabled = _next_scene_id().is_empty()
	continue_button.text = "继续查档" if not continue_button.disabled else "本卷已查清"


func _next_scene_id() -> String:
	if Chapter.definition == null:
		return ""
	for scene in Chapter.definition.scenes:
		var scene_id := str(scene.get("id", ""))
		if Chapter.scene_unlocked(scene_id) and not Chapter.scene_cleared(scene_id):
			return scene_id
	return ""


func _open_scene(scene_id: String) -> void:
	if not Chapter.scene_unlocked(scene_id):
		_toast("这一处还没有解锁")
		return
	GameState.current_scene_id = scene_id
	GameState.save_to()
	get_tree().change_scene_to_file(SCENE_PATH)


func _continue() -> void:
	var scene_id := _next_scene_id()
	if scene_id.is_empty():
		_toast("现场都已清点 · 可封存本卷")
		return
	_open_scene(scene_id)


func _open_ritual() -> void:
	GameState.save_to()
	get_tree().change_scene_to_file(RITUAL_PATH)


func _go_desk() -> void:
	GameState.save_to()
	get_tree().change_scene_to_file(DESK_PATH)


func _toast(message: String) -> void:
	toast.text = message
	toast_timer.start()


func _apply_debug_args() -> void:
	if not OS.is_debug_build():
		return
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo-all":
			for card_id in ["card_telegraph_1855", "card_chart_splice", "card_rayn_dissent", "card_sagar_note", "card_plate_press", "card_ledger_name", "card_plate_stack"]:
				GameState.collect_evidence(card_id, 10)
			for puzzle_id in ["P0", "P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8", "P9", "P10"]:
				Chapter.mark_done(puzzle_id)
			_build_rows()
			_refresh()
		elif arg == "--demo-progress":
			for card_id in ["card_telegraph_1855", "card_chart_splice", "card_rayn_dissent", "card_plate_press", "card_ledger_name"]:
				GameState.collect_evidence(card_id, 10)
			for puzzle_id in ["P0", "P1", "P2", "P3", "P4", "P5"]:
				Chapter.mark_done(puzzle_id)
			_build_rows()
			_refresh()
