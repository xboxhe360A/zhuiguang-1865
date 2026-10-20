extends Control
## 叠片：把五张底片拖到灯上，叠齐后彩色爆开，礼帽剪影浮出。

const SCENE_PATH := "res://scenes/scene_view.tscn"
const DOCK_RADIUS := 310.0
const CARD_SIZE := Vector2(196, 244)
const HOME_Y := 1400.0
const HOME_GAP := 210.0
const PLATE_TEXTURE := preload("res://assets/ui/trace_tracks.jpg")

@onready var arena: Control = %Arena
@onready var lamp: Control = %LampGlow
@onready var lamp_ring: Control = %LampRing
@onready var hat: HatReveal = %HatReveal
@onready var ribbon_label: Label = %RibbonLabel
@onready var prompt_label: Label = %PromptLabel
@onready var feedback_label: Label = %FeedbackLabel
@onready var hint_label: Label = %HintLabel
@onready var progress_label: Label = %ProgressLabel
@onready var back_button: Button = %BtnBack
@onready var result: Control = %Result
@onready var result_eyebrow: Label = %ResultEyebrow
@onready var result_title: Label = %ResultTitle
@onready var result_meta: Label = %ResultMeta
@onready var result_body: RichTextLabel = %ResultBody
@onready var return_button: Button = %BtnReturn

var _puzzle: Dictionary = {}
var _params: Dictionary = {}
var _plates: Array[PlateToken] = []
var _docked: Array[PlateToken] = []
var _finished := false
var _revealing := false
var _lamp_tween: Tween


func _ready() -> void:
	Audio.set_ambience("amb_darkroom")
	GameState.current_dossier_id = "dossier_wudu"
	_load_puzzle()
	_labels()
	_build_plates()
	back_button.pressed.connect(_return_to_scene)
	return_button.pressed.connect(_return_to_scene)
	_pulse_lamp()
	_apply_debug_args()


func _load_puzzle() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--puzzle="):
			GameState.current_puzzle_id = arg.trim_prefix("--puzzle=")
	_puzzle = Chapter.puzzle_def(GameState.current_puzzle_id)
	if _puzzle.is_empty():
		_puzzle = Chapter.puzzle_def("P10")
	_params = _puzzle.get("params", {})


func _labels() -> void:
	ribbon_label.text = tr("序卷 · 雾都    ｜    显影    ｜    %s") % tr(str(_puzzle.get("title", "灯下五张底片")))
	prompt_label.text = str(_params.get("prompt", ""))
	hint_label.text = str(_params.get("hint", "拖到底片灯上松手。五张叠齐，影像才会显色。"))
	feedback_label.text = "灯还亮着 · 五张底片在桌上。"
	progress_label.text = tr("已叠 0 / %d") % _plates_count()


func _plates_count() -> int:
	return maxi(_params.get("plates", []).size(), 1)


func _build_plates() -> void:
	var definitions: Array = _params.get("plates", [])
	var count := definitions.size()
	var arena_width := arena.size.x if arena.size.x > 0.0 else 1080.0
	for i in count:
		var plate := PlateToken.new()
		plate.size = CARD_SIZE
		plate.custom_minimum_size = CARD_SIZE
		plate.pivot_offset = CARD_SIZE * 0.5
		plate.set_meta("index", i)
		arena.add_child(plate)
		_build_plate_face(plate, definitions[i])
		var center := Vector2(arena_width * 0.5 + (float(i) - float(count - 1) * 0.5) * HOME_GAP, HOME_Y)
		plate.set_home(center - CARD_SIZE * 0.5)
		plate.dropped.connect(_on_plate_dropped)
		_plates.append(plate)


func _build_plate_face(plate: PlateToken, definition: Dictionary) -> void:
	var card := Panel.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _plate_style(definition.get("tint", Color(0.72, 0.66, 0.5))))
	plate.add_child(card)

	var texture := TextureRect.new()
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture.offset_left = 10
	texture.offset_top = 10
	texture.offset_right = -10
	texture.offset_bottom = -10
	texture.texture = PLATE_TEXTURE
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var tint: Color = definition.get("tint", Color(0.72, 0.66, 0.5))
	texture.self_modulate = Color(tint.r, tint.g, tint.b, 0.5)
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(texture)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.offset_left = 10
	shade.offset_top = 10
	shade.offset_right = -10
	shade.offset_bottom = -10
	shade.color = Color(0.02, 0.03, 0.035, 0.5)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(shade)

	var year := Label.new()
	year.text = str(definition.get("label", ""))
	year.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	year.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	year.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	year.add_theme_font_size_override("font_size", 46)
	year.add_theme_color_override("font_color", Color(0.94, 0.86, 0.66, 1))
	year.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	year.add_theme_constant_override("shadow_offset_x", 2)
	year.add_theme_constant_override("shadow_offset_y", 2)
	year.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(year)

	var caption := Label.new()
	caption.text = "PLATE"
	caption.anchor_left = 0.0
	caption.anchor_right = 1.0
	caption.anchor_top = 1.0
	caption.anchor_bottom = 1.0
	caption.offset_top = -42
	caption.offset_bottom = -12
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color(0.86, 0.8, 0.64, 0.85))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(caption)


func _plate_style(tint: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.075, 0.96)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(tint.r, tint.g, tint.b, 0.95)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 8)
	return style


func _pulse_lamp() -> void:
	_lamp_tween = create_tween().set_loops()
	_lamp_tween.tween_property(lamp, "modulate:a", 0.62, 1.4).set_trans(Tween.TRANS_SINE)
	_lamp_tween.tween_property(lamp, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE)


func _lamp_center() -> Vector2:
	return lamp.get_global_rect().get_center()


static func is_on_lamp(center: Vector2, lamp_center: Vector2, radius: float = DOCK_RADIUS) -> bool:
	return center.distance_to(lamp_center) <= radius


func _on_plate_dropped(plate: PlateToken) -> void:
	if _finished or _revealing or plate.docked:
		return
	var center := plate.global_position + plate.size * 0.5
	if not is_on_lamp(center, _lamp_center()):
		feedback_label.text = "没压到灯芯 · 再拖近一点。"
		plate.return_home()
		return
	_dock(plate)


func _dock(plate: PlateToken) -> void:
	Audio.play("wood", -7.0, 0.08)
	plate.disable_drag()
	_docked.append(plate)
	var index := _docked.size() - 1
	var offset := Vector2(float(index) * 10.0 - 20.0, float(index) * -6.0)
	var target := _lamp_center() + offset - plate.size * 0.5
	feedback_label.text = tr("叠上第 %d 张 · %s。") % [_docked.size(), _plate_year(plate)]
	progress_label.text = tr("已叠 %d / %d") % [_docked.size(), _plates.size()]
	var tween := create_tween().set_parallel(true)
	tween.tween_property(plate, "global_position", target, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(plate, "scale", Vector2(0.66, 0.66), 0.3)
	tween.tween_property(plate, "modulate:a", 0.82, 0.3)
	await tween.finished
	if _docked.size() >= _plates.size() and not _revealing:
		_reveal()


func _plate_year(plate: PlateToken) -> String:
	var index := int(plate.get_meta("index", 0))
	var definitions: Array = _params.get("plates", [])
	return str(definitions[index].get("label", "")) if index < definitions.size() else ""


func _reveal() -> void:
	_revealing = true
	Audio.play("chime", -5.0)
	if _lamp_tween != null:
		_lamp_tween.kill()
	feedback_label.text = "五张叠成一个点 · 彩色从灯芯涨开。"
	lamp.modulate = Color(1.35, 1.28, 1.05, 1)
	arena.move_child(hat, -1)
	hat.strength = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(hat, "strength", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(lamp, "scale", Vector2(1.16, 1.16), 0.9)
	await get_tree().create_timer(1.5).timeout
	_complete()
	_show_result()


func _complete() -> void:
	if _finished:
		return
	_finished = true
	Chapter.complete_puzzle(str(_puzzle.get("id", "")))
	GameState.save_to()


func _show_result() -> void:
	var card := Archive.get_card(str(_puzzle.get("card", "")))
	var extra := str(_params.get("result", ""))
	if card != null:
		result_title.text = tr(card.title)
		result_body.text = "%s\n\n%s" % [tr(card.body), tr(extra)]
	else:
		result_title.text = tr(str(_params.get("result_title", _puzzle.get("title", "已归档"))))
		result_body.text = tr(extra)
	result_eyebrow.text = str(_params.get("eyebrow", "显影 · FIVE PLATES"))
	var dossier := Archive.get_dossier("dossier_wudu")
	var got := 0
	if dossier != null:
		for c in dossier.evidence:
			if GameState.has_evidence(c.id):
				got += 1
		result_meta.text = tr("档案 WG-1865 ｜ 证据 %02d / %02d ｜ 五片叠齐") % [got, dossier.evidence.size()]
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
			_demo_solve.call_deferred()


func _demo_solve() -> void:
	for plate in _plates:
		_dock(plate)
