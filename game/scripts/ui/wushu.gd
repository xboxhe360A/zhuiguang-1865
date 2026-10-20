extends Control
## 序章巷战：三条来路落下威胁，进铜环时点对应方向格挡；四拍后选一招制住为首者。不设失败。

const SCENE_PATH := "res://scenes/scene_view.tscn"
const LANE_X: Array[float] = [0.2, 0.5, 0.8]
const LANE_NAMES: Array[String] = ["左", "中", "右"]
const START_RATIO := 0.23
const RING_RATIO := 0.7
const DEFAULT_WINDOW := 135.0
const FALL_SPEED := 480.0
const FIRST_BEAT := 0.9
const BEAT_GAP := 1.35
const DEFAULT_SEQUENCE: Array[int] = [0, 2, 1, 0]

@onready var arena: Control = %Arena
@onready var prompt_label: Label = %PromptLabel
@onready var feedback_label: Label = %FeedbackLabel
@onready var progress_label: Label = %ProgressLabel
@onready var hint_label: Label = %HintLabel
@onready var ribbon_label: Label = %RibbonLabel
@onready var back_button: Button = %BtnBack
@onready var result: Control = %Result
@onready var result_eyebrow: Label = %ResultEyebrow
@onready var result_title: Label = %ResultTitle
@onready var result_meta: Label = %ResultMeta
@onready var result_body: RichTextLabel = %ResultBody
@onready var return_button: Button = %BtnReturn

var _puzzle: Dictionary = {}
var _params: Dictionary = {}
var _lanes: Array[int] = []
var _moves: Array = []
var _correct_move := "reverse"
var _lane_buttons: Array[Button] = []
var _threats: Array[Dictionary] = []
var _spawned := 0
var _resolved := 0
var _hits := 0
var _elapsed := 0.0
var _running := false
var _awaiting_move := false
var _finished := false
var _move_panel: Control


func _ready() -> void:
	Audio.set_ambience("amb_field")
	GameState.current_dossier_id = "dossier_wudu"
	_load_puzzle()
	_labels()
	_build_lanes()
	back_button.pressed.connect(_return_to_scene)
	return_button.pressed.connect(_return_to_scene)
	_apply_debug_args()
	if _running:
		set_process(true)


func _load_puzzle() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--puzzle="):
			GameState.current_puzzle_id = arg.trim_prefix("--puzzle=")
	_puzzle = Chapter.puzzle_def(GameState.current_puzzle_id)
	if _puzzle.is_empty():
		_puzzle = Chapter.puzzle_def("P0")
	_params = _puzzle.get("params", {})
	var beats := int(_params.get("beats", 4))
	var lanes: Array = _params.get("lanes", [])
	for i in beats:
		_lanes.append(int(lanes[i]) if i < lanes.size() else int(DEFAULT_SEQUENCE[i % DEFAULT_SEQUENCE.size()]))
	_moves = _params.get("moves", [
		{"id": "reverse", "label": "反剪手腕"},
		{"id": "sweep", "label": "扫堂绊腿"},
		{"id": "staff", "label": "横杖压肩"},
	])
	_correct_move = str(_params.get("correct_move", "reverse"))


func _labels() -> void:
	ribbon_label.text = tr("序卷 · 雾都    ｜    巷战    ｜    %s") % tr(str(_puzzle.get("title", "后巷 · 三拍")))
	prompt_label.text = str(_params.get("prompt", ""))
	hint_label.text = str(_params.get("hint", "威胁线进入铜环时点对应方向格挡。"))
	feedback_label.text = "看清楚来路 · 四拍。"
	progress_label.text = tr("接住 0 / %d 拍") % _lanes.size()


func _build_lanes() -> void:
	for child in arena.get_children():
		arena.remove_child(child)
		child.queue_free()
	for i in LANE_X.size():
		var guide := ColorRect.new()
		guide.color = Color(0.85, 0.62, 0.36, 0.1)
		guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		guide.anchor_left = LANE_X[i]
		guide.anchor_right = LANE_X[i]
		guide.anchor_top = START_RATIO
		guide.anchor_bottom = RING_RATIO
		guide.offset_left = -2
		guide.offset_right = 2
		arena.add_child(guide)

		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.anchor_left = LANE_X[i]
		button.anchor_right = LANE_X[i]
		button.anchor_top = RING_RATIO
		button.anchor_bottom = RING_RATIO
		button.offset_left = -118
		button.offset_right = 118
		button.offset_top = -118
		button.offset_bottom = 118
		button.text = LANE_NAMES[i]
		button.add_theme_font_size_override("font_size", 40)
		button.add_theme_color_override("font_color", Color(0.95, 0.83, 0.58, 1))
		button.add_theme_stylebox_override("normal", _ring_style(false))
		button.add_theme_stylebox_override("hover", _ring_style(true))
		button.add_theme_stylebox_override("pressed", _ring_style(true, true))
		button.pressed.connect(_on_lane_pressed.bind(i))
		arena.add_child(button)
		_lane_buttons.append(button)

		var tag := Label.new()
		tag.text = tr("第 %d 路") % (i + 1)
		tag.anchor_left = LANE_X[i]
		tag.anchor_right = LANE_X[i]
		tag.anchor_top = RING_RATIO
		tag.anchor_bottom = RING_RATIO
		tag.offset_left = -120
		tag.offset_right = 120
		tag.offset_top = 128
		tag.offset_bottom = 168
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 22)
		tag.add_theme_color_override("font_color", Color(0.72, 0.72, 0.62, 0.9))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arena.add_child(tag)
	_running = true


func _ring_style(hover: bool, tapped: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.05, 0.72) if not hover else Color(0.22, 0.16, 0.09, 0.82)
	if tapped:
		style.bg_color = Color(0.3, 0.22, 0.1, 0.9)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color(0.95, 0.72, 0.4, 0.95)
	style.corner_radius_top_left = 118
	style.corner_radius_top_right = 118
	style.corner_radius_bottom_left = 118
	style.corner_radius_bottom_right = 118
	style.shadow_color = Color(0.95, 0.68, 0.38, 0.28)
	style.shadow_size = 26
	return style


func _spawn_threat(lane: int) -> void:
	var token := Panel.new()
	token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token.size = Vector2(88, 88)
	var x := arena.size.x * LANE_X[lane] - 44
	var y := arena.size.y * START_RATIO - 44
	token.position = Vector2(x, y)
	token.add_theme_stylebox_override("panel", _token_style())
	arena.add_child(token)

	var mark := Label.new()
	mark.text = "!"
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", 44)
	mark.add_theme_color_override("font_color", Color(0.16, 0.1, 0.04, 1))
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token.add_child(mark)

	_threats.append({"node": token, "lane": lane, "y": y + 44.0, "resolved": false})


func _token_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.75, 0.42, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1, 0.93, 0.72, 1)
	style.corner_radius_top_left = 44
	style.corner_radius_top_right = 44
	style.corner_radius_bottom_left = 44
	style.corner_radius_bottom_right = 44
	style.shadow_color = Color(0.95, 0.68, 0.3, 0.55)
	style.shadow_size = 18
	return style


static func hit_window_contains(token_y: float, ring_y: float, window: float = DEFAULT_WINDOW) -> bool:
	return absf(token_y - ring_y) <= window


func _ring_y() -> float:
	return arena.size.y * RING_RATIO


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	while _spawned < _lanes.size() and _elapsed >= FIRST_BEAT + float(_spawned) * BEAT_GAP:
		_spawn_threat(_lanes[_spawned])
		_spawned += 1

	var ring_y := _ring_y()
	for threat in _threats:
		if bool(threat.get("resolved", false)):
			continue
		var node: Control = threat["node"]
		if not is_instance_valid(node):
			threat["resolved"] = true
			continue
		var y := float(threat["y"]) + FALL_SPEED * delta
		threat["y"] = y
		node.position.y = y - node.size.y * 0.5
		var near := hit_window_contains(y, ring_y)
		node.modulate = Color(1, 1, 0.72) if near else Color(1, 1, 1)
		if y > ring_y + DEFAULT_WINDOW:
			threat["resolved"] = true
			_resolved += 1
			_miss(node)
	if _spawned >= _lanes.size() and _resolved >= _lanes.size() and not _awaiting_move:
		_finish_rhythm()


func _miss(node: Control) -> void:
	feedback_label.text = "这一拍贴着头皮过去了 · 不急。"
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 0.0, 0.25)
	tween.tween_callback(node.queue_free)


func _on_lane_pressed(lane: int) -> void:
	if _finished or _awaiting_move:
		return
	var ring_y := _ring_y()
	var best: Dictionary = {}
	for threat in _threats:
		if bool(threat.get("resolved", false)) or int(threat["lane"]) != lane:
			continue
		var node: Control = threat["node"]
		if not is_instance_valid(node):
			continue
		var distance := absf(float(threat["y"]) - ring_y)
		if distance <= DEFAULT_WINDOW and (best.is_empty() or distance < float(best["distance"])):
			best = {"threat": threat, "distance": distance}
	if best.is_empty():
		Audio.play("pencil", -12.0)
		feedback_label.text = tr("%s路空拍 · 手别比眼快。") % tr(LANE_NAMES[lane])
		return
	var threat: Dictionary = best["threat"]
	threat["resolved"] = true
	_resolved += 1
	_hits += 1
	var node: Control = threat["node"]
	Audio.play("wood", -4.0, 0.06)
	node.modulate = Color(0.72, 0.92, 0.6, 1)
	feedback_label.text = tr("接住第 %d 拍 · %s路。") % [_hits, tr(LANE_NAMES[lane])]
	progress_label.text = tr("接住 %d / %d 拍") % [_hits, _lanes.size()]
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(1.35, 1.35), 0.08)
	tween.parallel().tween_property(node, "modulate:a", 0.0, 0.2)
	tween.tween_callback(node.queue_free)


func _finish_rhythm() -> void:
	if _awaiting_move:
		return
	_awaiting_move = true
	_running = false
	set_process(false)
	feedback_label.text = "四拍已过。为首的人还在门槛上——选一招。"
	await get_tree().create_timer(0.5).timeout
	_show_moves()


func _show_moves() -> void:
	if _finished or _move_panel != null:
		return
	_move_panel = PanelContainer.new()
	_move_panel.anchor_left = 0.5
	_move_panel.anchor_right = 0.5
	_move_panel.anchor_top = 0.5
	_move_panel.anchor_bottom = 0.5
	_move_panel.offset_left = -420
	_move_panel.offset_right = 420
	_move_panel.offset_top = -272
	_move_panel.offset_bottom = 272
	_move_panel.add_theme_stylebox_override("panel", _move_panel_style())
	arena.add_child(_move_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	_move_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	var title := Label.new()
	title.text = "收势 · 一招"
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.93, 0.84, 0.64, 1))
	box.add_child(title)

	var note := Label.new()
	note.text = tr("接住 %d / %d 拍。为首者持短棍，右肩在前。") % [_hits, _lanes.size()]
	note.add_theme_font_size_override("font_size", 22)
	note.add_theme_color_override("font_color", Color(0.66, 0.71, 0.68, 1))
	box.add_child(note)

	for move in _moves:
		var move_id := str(move.get("id", ""))
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 88)
		button.focus_mode = Control.FOCUS_NONE
		button.text = str(move.get("label", move_id))
		button.add_theme_font_size_override("font_size", 30)
		button.pressed.connect(_on_move_pressed.bind(move_id, button))
		box.add_child(button)

	var retry := Label.new()
	retry.text = "选错不罚 · 看清来路再试"
	retry.add_theme_font_size_override("font_size", 20)
	retry.add_theme_color_override("font_color", Color(0.6, 0.65, 0.62, 1))
	box.add_child(retry)


func _move_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.027, 0.05, 0.058, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.725, 0.639, 0.384, 0.55)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 24
	style.shadow_offset = Vector2(0, 10)
	return style


func _on_move_pressed(move_id: String, button: Button) -> void:
	if _finished:
		return
	if move_id != _correct_move:
		Audio.play("wrong", -9.0)
		feedback_label.text = "他沉肩让过 · 换一招，不用急。"
		var tween := create_tween()
		tween.tween_property(button, "modulate", Color(0.95, 0.5, 0.4, 1), 0.08)
		tween.tween_property(button, "modulate", Color(1, 1, 1, 1), 0.25)
		return
	button.modulate = Color(0.72, 0.92, 0.6, 1)
	Audio.play("chime", -4.0)
	for child in button.get_parent().get_children():
		if child is Button:
			child.disabled = true
	feedback_label.text = "反剪 · 短棍落在积水里。"
	_complete.call_deferred()


func _complete() -> void:
	if _finished:
		return
	_finished = true
	Chapter.complete_puzzle(str(_puzzle.get("id", "")))
	GameState.save_to()
	await get_tree().create_timer(0.45).timeout
	_show_result()


func _show_result() -> void:
	var card := Archive.get_card(str(_puzzle.get("card", "")))
	var extra := str(_params.get("result", ""))
	if card != null:
		result_title.text = tr(card.title)
		result_body.text = "%s\n\n%s" % [tr(card.body), tr(extra)]
	else:
		result_title.text = tr(str(_params.get("result_title", _puzzle.get("title", "已归档"))))
		result_body.text = tr(extra)
	result_eyebrow.text = str(_params.get("eyebrow", "档案 · 第一课"))
	var dossier := Archive.get_dossier("dossier_wudu")
	var got := 0
	if dossier != null:
		for c in dossier.evidence:
			if GameState.has_evidence(c.id):
				got += 1
		result_meta.text = tr("档案 WG-1865 ｜ 证据 %02d / %02d ｜ 接住 %d / %d 拍") % [got, dossier.evidence.size(), _hits, _lanes.size()]
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
			_complete.call_deferred()
		elif arg == "--demo-ready":
			_running = false
			_awaiting_move = true
			set_process(false)
			_show_moves.call_deferred()
