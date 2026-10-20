extends Control
## 实物谜题屏：清点 / 座位 / 货箱 / 测深 / 抽屉 / 图件配对，共用一套档案层 UI。

const SCENE_PATH := "res://scenes/scene_view.tscn"
const CHART_TEXTURE := preload("res://assets/ui/chart_trace.jpg")

@onready var bg: TextureRect = %Bg
@onready var board: Control = %Board
@onready var ribbon_label: Label = %RibbonLabel
@onready var prompt_label: Label = %PromptLabel
@onready var feedback_label: Label = %FeedbackLabel
@onready var clue_label: Label = %ClueLabel
@onready var progress_label: Label = %ProgressLabel
@onready var action_button: Button = %BtnAction
@onready var back_button: Button = %BtnBack
@onready var result: Control = %Result
@onready var result_eyebrow: Label = %ResultEyebrow
@onready var result_title: Label = %ResultTitle
@onready var result_meta: Label = %ResultMeta
@onready var result_body: RichTextLabel = %ResultBody
@onready var return_button: Button = %BtnReturn

var _puzzle: Dictionary = {}
var _params: Dictionary = {}
var _mode := ""
var _finished := false
var _found := 0
var _sequence: Array[int] = []
var _selected: Array[String] = []


func _ready() -> void:
	GameState.current_dossier_id = "dossier_wudu"
	_load_puzzle()
	_background()
	_labels()
	_build()
	back_button.pressed.connect(_return_to_scene)
	return_button.pressed.connect(_return_to_scene)
	_apply_debug_args()


func _load_puzzle() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--puzzle="):
			GameState.current_puzzle_id = arg.trim_prefix("--puzzle=")
	_puzzle = Chapter.puzzle_def(GameState.current_puzzle_id)
	if _puzzle.is_empty():
		_puzzle = Chapter.puzzle_def("P1")
	_params = _puzzle.get("params", {})
	_mode = str(_params.get("mode", "find_all"))


func _background() -> void:
	var path := str(_params.get("bg", ""))
	if path.is_empty():
		return
	var texture := load(path) as Texture2D
	if texture != null:
		bg.texture = texture


func _labels() -> void:
	ribbon_label.text = "序卷 · 雾都    ｜    实物    ｜    %s" % str(_puzzle.get("title", ""))
	prompt_label.text = str(_params.get("prompt", ""))
	clue_label.text = str(_params.get("clue", ""))
	feedback_label.text = str(_params.get("hint", ""))
	progress_label.text = ""
	action_button.visible = false


func _build() -> void:
	for child in board.get_children():
		board.remove_child(child)
		child.queue_free()
	match _mode:
		"find_all":
			_build_find_all()
		"pick_one":
			_build_seats()
		"crate_sum":
			_build_crates()
		"dial":
			_build_dial()
		"sequence":
			_build_sequence()
		"pair":
			_build_pair()
		_:
			feedback_label.text = "尚未接入的谜题模式：%s" % _mode


func _complete() -> void:
	if _finished:
		return
	_finished = true
	Chapter.complete_puzzle(str(_puzzle.get("id", "")))
	GameState.save_to()
	await get_tree().create_timer(0.35).timeout
	_show_result()


func _show_result() -> void:
	var card := Archive.get_card(str(_puzzle.get("card", "")))
	var extra := str(_params.get("result", ""))
	if card != null:
		result_title.text = card.title
		result_body.text = "%s\n\n%s" % [card.body, extra]
	else:
		result_title.text = str(_params.get("result_title", _puzzle.get("title", "已归档")))
		result_body.text = extra
	var dossier := Archive.get_dossier("dossier_wudu")
	var got := 0
	if dossier != null:
		for c in dossier.evidence:
			if GameState.has_evidence(c.id):
				got += 1
		result_meta.text = "档案 WG-1865 ｜ 证据 %02d / %02d ｜ %s" % [got, dossier.evidence.size(), str(_params.get("eyebrow", "已归档"))]
	result_eyebrow.text = str(_params.get("eyebrow", "档案 · FILED"))
	result.visible = true
	result.modulate.a = 0.0
	create_tween().tween_property(result, "modulate:a", 1.0, 0.25)


func _return_to_scene() -> void:
	GameState.save_to()
	get_tree().change_scene_to_file(SCENE_PATH)


# ---------------------------------------------------------------- 清点

func _build_find_all() -> void:
	var board_width := board.size.x if board.size.x > 0.0 else 1080.0
	var area := Rect2(0.0, 350.0, board_width, 1200.0)
	var texture := load(str(_params.get("flatlay", _params.get("bg", "")))) as Texture2D
	if texture == null:
		feedback_label.text = "实物图缺失"
		return
	var aspect := texture.get_size().x / texture.get_size().y
	var height := area.size.y
	var width := height * aspect
	if width > area.size.x:
		width = area.size.x
		height = width / aspect
	var frame_rect := Rect2(
		Vector2((area.size.x - width) * 0.5, area.position.y + (area.size.y - height) * 0.5) - Vector2(14, 14),
		Vector2(width, height) + Vector2(28, 28)
	)
	var frame := Panel.new()
	frame.position = frame_rect.position
	frame.size = frame_rect.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _flatlay_frame_style())
	board.add_child(frame)

	var flatlay := TextureRect.new()
	flatlay.position = frame_rect.position + Vector2(14, 14)
	flatlay.size = Vector2(width, height)
	flatlay.texture = texture
	flatlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flatlay.stretch_mode = TextureRect.STRETCH_SCALE
	flatlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(flatlay)

	var items: Array = _params.get("items", [])
	for item in items:
		var pos: Vector2 = item.get("pos", Vector2(0.5, 0.5))
		var button := _round_button(pos, 58.0)
		button.pressed.connect(_on_item_pressed.bind(item, button))
		flatlay.add_child(button)
	_update_progress()


func _flatlay_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.065, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.62, 0.52, 0.32, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 26
	style.shadow_offset = Vector2(0, 12)
	return style


func _on_item_pressed(item: Dictionary, button: Button) -> void:
	if _finished:
		return
	if bool(item.get("ok", false)):
		if button.disabled:
			return
		_found += 1
		button.disabled = true
		button.text = "✓"
		button.modulate = Color(0.75, 0.9, 0.62, 1)
		feedback_label.text = "%s · 清单第 %d 件" % [str(item.get("name", "")), _found]
		_update_progress()
		if _found >= int(_params.get("require", _correct_item_count())):
			_complete()
	else:
		feedback_label.text = "%s · 清单上没有这一件" % str(item.get("name", ""))
		_flash(button, Color(0.95, 0.45, 0.35, 1))


func _correct_item_count() -> int:
	var count := 0
	for item in _params.get("items", []):
		if bool(item.get("ok", false)):
			count += 1
	return count


func _update_progress() -> void:
	progress_label.text = "已点出 %d / %d 件" % [_found, _correct_item_count()]


func _round_button(pos: Vector2, radius: float) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.anchor_left = pos.x
	button.anchor_top = pos.y
	button.anchor_right = pos.x
	button.anchor_bottom = pos.y
	button.offset_left = -radius
	button.offset_top = -radius
	button.offset_right = radius
	button.offset_bottom = radius
	button.add_theme_font_size_override("font_size", 40)
	button.add_theme_color_override("font_color", Color(0.95, 0.82, 0.52, 1))
	button.add_theme_stylebox_override("normal", _circle_style(false))
	button.add_theme_stylebox_override("hover", _circle_style(true))
	button.add_theme_stylebox_override("pressed", _circle_style(true))
	button.add_theme_stylebox_override("disabled", _circle_style(false, true))
	return button


func _circle_style(hover: bool, done: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.56, 0.34, 0.12 if hover else 0.05)
	if done:
		style.bg_color = Color(0.2, 0.32, 0.2, 0.25)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.95, 0.69, 0.47, 1) if not done else Color(0.62, 0.86, 0.58, 0.8)
	style.corner_radius_top_left = 90
	style.corner_radius_top_right = 90
	style.corner_radius_bottom_left = 90
	style.corner_radius_bottom_right = 90
	style.shadow_color = Color(0.85, 0.56, 0.34, 0.35)
	style.shadow_size = 18
	return style


# ---------------------------------------------------------------- 座位

func _build_seats() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -470
	panel.offset_top = -350
	panel.offset_right = 470
	panel.offset_bottom = 350
	panel.add_theme_stylebox_override("panel", _panel_style())
	board.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = "旁听席 · 座位表"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.91, 0.83, 0.63, 1))
	box.add_child(title)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	var corner := Control.new()
	corner.custom_minimum_size = Vector2(92, 0)
	header.add_child(corner)
	for c in int(_params.get("cols", 6)):
		if c == int(_params.get("aisle_after", 3)):
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(34, 0)
			header.add_child(gap)
		var label := Label.new()
		label.text = "ABCDEF".substr(c, 1)
		label.custom_minimum_size = Vector2(104, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(0.55, 0.64, 0.68, 1))
		header.add_child(label)

	for r in int(_params.get("rows", 4)):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var row_label := Label.new()
		row_label.text = "第%d排" % (r + 1)
		row_label.custom_minimum_size = Vector2(92, 0)
		row_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row_label.add_theme_font_size_override("font_size", 20)
		row_label.add_theme_color_override("font_color", Color(0.55, 0.64, 0.68, 1))
		row.add_child(row_label)
		for c in int(_params.get("cols", 6)):
			if c == int(_params.get("aisle_after", 3)):
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(34, 0)
				row.add_child(gap)
			var seat := Button.new()
			seat.custom_minimum_size = Vector2(104, 82)
			seat.focus_mode = Control.FOCUS_NONE
			var seat_id := "%s%d" % ["ABCDEF".substr(c, 1), r + 1]
			seat.text = seat_id
			seat.add_theme_font_size_override("font_size", 21)
			seat.add_theme_stylebox_override("normal", _seat_style(false))
			seat.add_theme_stylebox_override("hover", _seat_style(true))
			seat.add_theme_stylebox_override("pressed", _seat_style(true))
			seat.pressed.connect(_on_seat_pressed.bind(seat_id, seat))
			row.add_child(seat)


func _seat_style(hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.17, 0.18, 0.9) if hover else Color(0.04, 0.07, 0.08, 0.85)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.85, 0.74, 0.45, 0.8) if hover else Color(0.55, 0.6, 0.58, 0.45)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func _on_seat_pressed(seat_id: String, seat: Button) -> void:
	if _finished:
		return
	if seat_id == str(_params.get("correct", "")):
		feedback_label.text = "%s · 座位缝里有一角报纸。" % seat_id
		seat.modulate = Color(0.75, 0.9, 0.62, 1)
		_complete()
		return
	_flash(seat, Color(0.95, 0.45, 0.35, 1))
	var row := int(seat_id.substr(1)) - 1
	var col := "ABCDEF".find(seat_id.substr(0, 1))
	if row == 0 or row == int(_params.get("rows", 4)) - 1:
		feedback_label.text = "%s · 首排太显眼，末排听不清。" % seat_id
	elif col < int(_params.get("aisle_after", 3)):
		feedback_label.text = "%s · 左区离煤气灯太远。" % seat_id
	elif col >= int(_params.get("cols", 6)) - 1:
		feedback_label.text = "%s · 右手边没有空位。" % seat_id
	else:
		feedback_label.text = "%s · 右手边坐着人。" % seat_id


# ---------------------------------------------------------------- 货箱

func _build_crates() -> void:
	for crate in _params.get("crates", []):
		var pos: Vector2 = crate.get("pos", Vector2(0.5, 0.5))
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.anchor_left = pos.x
		button.anchor_top = pos.y
		button.anchor_right = pos.x
		button.anchor_bottom = pos.y
		button.offset_left = -95
		button.offset_top = -64
		button.offset_right = 95
		button.offset_bottom = 64
		button.text = "%s\n%d 担" % [str(crate.get("label", "?")), int(crate.get("weight", 0))]
		button.add_theme_font_size_override("font_size", 28)
		button.set_meta("weight", int(crate.get("weight", 0)))
		button.set_meta("label", str(crate.get("label", "?")))
		button.add_theme_stylebox_override("normal", _crate_style(false))
		button.add_theme_stylebox_override("hover", _crate_style(true))
		button.add_theme_stylebox_override("pressed", _crate_style(true, true))
		button.toggled.connect(_on_crate_toggled)
		board.add_child(button)
	action_button.visible = true
	action_button.text = "吊装过秤"
	action_button.disabled = true
	action_button.pressed.connect(_submit_crates)
	_update_crate_progress()


func _crate_style(hover: bool, selected: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.3, 0.16, 0.85) if selected else (Color(0.16, 0.2, 0.19, 0.9) if hover else Color(0.07, 0.11, 0.11, 0.88))
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.95, 0.78, 0.46, 1) if selected else Color(0.65, 0.56, 0.36, 0.7)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 10
	return style


func _on_crate_toggled(_pressed: bool) -> void:
	_update_crate_progress()


func _selected_crates() -> Array[Button]:
	var result: Array[Button] = []
	for child in board.get_children():
		if child is Button and child.toggle_mode and child.button_pressed:
			result.append(child)
	return result


func _update_crate_progress() -> void:
	var total := 0
	var selected := _selected_crates()
	for crate in selected:
		total += int(crate.get_meta("weight", 0))
	progress_label.text = "已选 %d / %d 箱 · 合计 %d 长担（提单 72）" % [selected.size(), int(_params.get("pick", 3)), total]
	action_button.disabled = selected.size() != int(_params.get("pick", 3))
	if selected.size() > int(_params.get("pick", 3)):
		feedback_label.text = "只吊三箱 · 多选的先卸下。"


func _submit_crates() -> void:
	var total := 0
	for crate in _selected_crates():
		total += int(crate.get_meta("weight", 0))
	if total == int(_params.get("target", 72)):
		feedback_label.text = "过秤 · 七十二长担，正好。"
		_complete()
	else:
		feedback_label.text = "过秤 · %d 长担。提单要 72，差 %d。" % [total, absi(total - int(_params.get("target", 72)))]
		_flash(action_button, Color(0.95, 0.45, 0.35, 1))


# ---------------------------------------------------------------- 测深

func _build_dial() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -420
	panel.offset_top = -250
	panel.offset_right = 420
	panel.offset_bottom = 250
	panel.add_theme_stylebox_override("panel", _panel_style())
	board.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	var caption := Label.new()
	caption.text = "写入日志的垂直深度"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_color", Color(0.66, 0.71, 0.68, 1))
	box.add_child(caption)

	var reading := float(_params.get("reading", _params.get("min", 20) + 20))
	var value_label := Label.new()
	value_label.name = "ValueLabel"
	value_label.text = "%d 拓" % int(reading)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 64)
	value_label.add_theme_color_override("font_color", Color(0.91, 0.83, 0.63, 1))
	box.add_child(value_label)

	var slider := HSlider.new()
	slider.min_value = float(_params.get("min", 20))
	slider.max_value = float(_params.get("max", 50))
	slider.step = float(_params.get("step", 1))
	slider.value = reading
	slider.custom_minimum_size = Vector2(0, 60)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%d %s" % [int(value), str(_params.get("unit", "拓"))]
	)
	box.add_child(slider)

	var note := Label.new()
	note.text = "先按读数修正，再拖动滑尺"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 22)
	note.add_theme_color_override("font_color", Color(0.55, 0.64, 0.68, 1))
	box.add_child(note)

	action_button.visible = true
	action_button.text = "记入日志"
	action_button.pressed.connect(func() -> void:
		var target := float(_params.get("target", 35))
		var tolerance := float(_params.get("tolerance", 1))
		if absf(slider.value - target) <= tolerance:
			feedback_label.text = "日志记下：%d %s。" % [int(slider.value), str(_params.get("unit", "拓"))]
			_complete()
		else:
			feedback_label.text = "与修正值不符。再算一遍：读数 × cos 夹角。"
			_flash(action_button, Color(0.95, 0.45, 0.35, 1))
	)
	progress_label.text = "读数 40 拓 · 夹角 30° · cos 30° ≈ 0.866"


# ---------------------------------------------------------------- 抽屉

func _build_sequence() -> void:
	for i in _params.get("latches", []).size():
		var latch: Dictionary = _params.get("latches", [])[i]
		var pos: Vector2 = latch.get("pos", Vector2(0.5, 0.5))
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.anchor_left = pos.x
		button.anchor_top = pos.y
		button.anchor_right = pos.x
		button.anchor_bottom = pos.y
		button.offset_left = -92
		button.offset_top = -92
		button.offset_right = 92
		button.offset_bottom = 92
		button.text = str(latch.get("label", ""))
		button.add_theme_font_size_override("font_size", 28)
		button.add_theme_stylebox_override("normal", _circle_style(false))
		button.add_theme_stylebox_override("hover", _circle_style(true))
		button.add_theme_stylebox_override("pressed", _circle_style(true))
		button.pressed.connect(_on_latch_pressed.bind(i, button))
		board.add_child(button)
	progress_label.text = "按顺序按下三个铜扣"


func _on_latch_pressed(index: int, button: Button) -> void:
	if _finished:
		return
	_sequence.append(index)
	var labels: Array = _params.get("correct", [])
	var expected: Array = labels.slice(0, _sequence.size())
	if _sequence != expected:
		feedback_label.text = "顺序不对 · 压痕重排。"
		_sequence.clear()
		_flash(button, Color(0.95, 0.45, 0.35, 1))
		progress_label.text = "从第一扣重新开始"
		return
	feedback_label.text = "第 %d 扣 · %s" % [_sequence.size(), str(button.text)]
	button.modulate = Color(0.75, 0.9, 0.62, 1)
	progress_label.text = "已按 %d / %d 扣" % [_sequence.size(), labels.size()]
	if _sequence.size() == labels.size():
		_complete()


# ---------------------------------------------------------------- 图件配对

func _build_pair() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -450
	panel.offset_top = -380
	panel.offset_right = 450
	panel.offset_bottom = 380
	panel.add_theme_stylebox_override("panel", _panel_style())
	board.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	margin.add_child(grid)

	for fragment in _params.get("fragments", []):
		var card := Button.new()
		card.toggle_mode = true
		card.focus_mode = Control.FOCUS_NONE
		card.custom_minimum_size = Vector2(390, 300)
		card.clip_contents = true
		card.add_theme_stylebox_override("normal", _fragment_style(false))
		card.add_theme_stylebox_override("hover", _fragment_style(true))
		card.add_theme_stylebox_override("pressed", _fragment_style(true, true))
		card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		grid.add_child(card)

		var texture := TextureRect.new()
		texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var source := CHART_TEXTURE
		if fragment.has("texture"):
			var loaded := load(str(fragment.get("texture"))) as Texture2D
			if loaded != null:
				source = loaded
		var region = fragment.get("region", null)
		if region is Rect2:
			var atlas := AtlasTexture.new()
			atlas.atlas = source
			atlas.region = region
			texture.texture = atlas
		else:
			texture.texture = source
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var tint: Color = fragment.get("tint", Color(0.8, 0.8, 0.8))
		texture.self_modulate = Color(tint.r, tint.g, tint.b, 0.62)
		texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(texture)

		var shade := ColorRect.new()
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.color = Color(0.02, 0.04, 0.04, 0.24)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(shade)

		var caption_band := ColorRect.new()
		caption_band.anchor_left = 0.0
		caption_band.anchor_top = 1.0
		caption_band.anchor_right = 1.0
		caption_band.anchor_bottom = 1.0
		caption_band.offset_top = -104.0
		caption_band.color = Color(0.02, 0.035, 0.03, 0.82)
		caption_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(caption_band)

		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 24
		box.offset_top = 24
		box.offset_right = -24
		box.offset_bottom = -24
		box.alignment = BoxContainer.ALIGNMENT_END
		box.add_theme_constant_override("separation", 4)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(box)

		var name_label := Label.new()
		name_label.text = str(fragment.get("name", ""))
		name_label.add_theme_font_size_override("font_size", 27)
		name_label.add_theme_color_override("font_color", Color(0.93, 0.86, 0.68, 1))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(name_label)

		var note_label := Label.new()
		note_label.text = str(fragment.get("note", ""))
		note_label.add_theme_font_size_override("font_size", 21)
		note_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.64, 1))
		note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(note_label)

		card.set_meta("fragment_id", str(fragment.get("id", "")))
		card.toggled.connect(_on_fragment_toggled)

	action_button.visible = true
	action_button.text = "并置比对"
	action_button.disabled = true
	action_button.pressed.connect(_submit_pair)
	progress_label.text = "选中两张图件"


func _fragment_style(hover: bool, selected: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.2, 0.16, 0.9) if selected else (Color(0.08, 0.12, 0.11, 0.92) if not hover else Color(0.12, 0.17, 0.16, 0.94))
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.95, 0.78, 0.46, 1) if selected else Color(0.6, 0.55, 0.4, 0.7)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 14
	return style


func _on_fragment_toggled(_pressed: bool) -> void:
	_selected.clear()
	for child in board.find_children("*", "Button", true, false):
		if child is Button and child.toggle_mode and child.button_pressed:
			_selected.append(str(child.get_meta("fragment_id", "")))
	progress_label.text = "已选 %d / 2 张" % _selected.size()
	action_button.disabled = _selected.size() != 2
	if _selected.size() > 2:
		feedback_label.text = "只比对两张。"


func _submit_pair() -> void:
	var correct: Array = _params.get("correct", [])
	var a := str(_selected[0]) if _selected.size() > 0 else ""
	var b := str(_selected[1]) if _selected.size() > 1 else ""
	if (a == str(correct[0]) and b == str(correct[1])) or (a == str(correct[1]) and b == str(correct[0])):
		feedback_label.text = "两张图的潮痕咬合 · 同一段海岸。"
		_complete()
	else:
		feedback_label.text = "两张图的潮痕位置对不上。"
		_flash(action_button, Color(0.95, 0.45, 0.35, 1))


# ---------------------------------------------------------------- 通用

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.027, 0.05, 0.058, 0.93)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.725, 0.639, 0.384, 0.5)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 20
	style.shadow_offset = Vector2(0, 10)
	return style


func _flash(control: Control, color: Color) -> void:
	var original := control.modulate
	var tween := create_tween()
	tween.tween_property(control, "modulate", color, 0.08)
	tween.tween_property(control, "modulate", original, 0.28)


func _apply_debug_args() -> void:
	if not OS.is_debug_build():
		return
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo-solved":
			_complete.call_deferred()
