extends Control
## 现场屏：按章节数据装配背景与热点，接入五类谜题与证据卡图鉴。

const DOSSIER_ID := "dossier_wudu"
const INDEX_PATH := "res://scenes/chapter_index.tscn"
const KIND_SCENES := {
	"wushu": "res://scenes/wushu.tscn",
	"field": "res://scenes/field_puzzle.tscn",
	"align": "res://scenes/light_table.tscn",
	"develop": "res://scenes/developing.tscn",
	"stack": "res://scenes/plate_stack.tscn",
}
const SLOT_NUMERALS: Array[String] = ["壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖"]

@onready var bg: TextureRect = %Bg
@onready var ribbon_label: Label = %RibbonLabel
@onready var hotspots: Control = %Hotspots
@onready var hint: Label = %Hint
@onready var portholes: HBoxContainer = %Portholes
@onready var sheet: Control = %EvidenceSheet
@onready var sheet_title: Label = %SheetTitle
@onready var sheet_voice: Label = %SheetVoice
@onready var sheet_meta: Label = %SheetMeta
@onready var sheet_body: RichTextLabel = %SheetBody
@onready var sheet_source: Label = %SheetSource
@onready var take_button: Button = %BtnTake
@onready var close_button: Button = %BtnClose
@onready var back_button: Button = %BtnBack
@onready var toast: Label = %Toast
@onready var toast_timer: Timer = %ToastTimer

var _scene: Dictionary = {}
var _card: EvidenceCard
var _collected_cards: Array[EvidenceCard] = []
var _pulses: Array[Tween] = []


func _ready() -> void:
	Audio.set_ambience("amb_field")
	GameState.current_dossier_id = DOSSIER_ID
	back_button.pressed.connect(_go_back)
	take_button.pressed.connect(_on_take_pressed)
	close_button.pressed.connect(_close_sheet)
	toast_timer.timeout.connect(func() -> void: toast.text = "")
	_apply_debug_args()
	_ensure_scene()
	_refresh()


func _ensure_scene() -> void:
	var scene_id := GameState.current_scene_id
	if scene_id.is_empty() or Chapter.scene_def(scene_id).is_empty() or not Chapter.scene_unlocked(scene_id):
		scene_id = _first_available_scene()
		GameState.current_scene_id = scene_id
	_scene = Chapter.scene_def(scene_id)


func _first_available_scene() -> String:
	if Chapter.definition == null:
		return ""
	for scene in Chapter.definition.scenes:
		var scene_id := str(scene.get("id", ""))
		if Chapter.scene_unlocked(scene_id) and not Chapter.scene_cleared(scene_id):
			return scene_id
	return str(Chapter.definition.scenes[0].get("id", "")) if not Chapter.definition.scenes.is_empty() else ""


func _refresh() -> void:
	if _scene.is_empty():
		hint.text = "卷宗数据缺失"
		return
	_apply_background()
	_build_hotspots()
	_refresh_hint()
	_refresh_slots()
	ribbon_label.text = tr("序卷 · 雾都    ｜    %s    ｜    证据 %d / %d") % [
		tr(str(_scene.get("title", ""))),
		_collected_cards.size(),
		Archive.get_dossier(DOSSIER_ID).evidence.size(),
	]


func _apply_background() -> void:
	var path := str(_scene.get("bg", ""))
	if path.is_empty():
		return
	var texture := load(path) as Texture2D
	if texture != null:
		bg.texture = texture


func _build_hotspots() -> void:
	for tween in _pulses:
		if tween != null:
			tween.kill()
	_pulses.clear()
	for child in hotspots.get_children():
		hotspots.remove_child(child)
		child.queue_free()

	for hotspot in _scene.get("hotspots", []):
		var puzzle_id := str(hotspot.get("puzzle", ""))
		var puzzle := Chapter.puzzle_def(puzzle_id)
		if puzzle.is_empty():
			continue
		var done := Chapter.is_done(puzzle_id)
		var radius := float(hotspot.get("radius", 110))
		var pos: Vector2 = hotspot.get("pos", Vector2(0.5, 0.5))
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
		button.text = "✓" if done else ""
		button.add_theme_font_size_override("font_size", 40)
		button.add_theme_color_override("font_color", Color(0.95, 0.82, 0.52, 1))
		button.add_theme_stylebox_override("normal", _hotspot_style(done, false))
		button.add_theme_stylebox_override("hover", _hotspot_style(done, true))
		button.add_theme_stylebox_override("pressed", _hotspot_style(done, true))
		button.tooltip_text = str(hotspot.get("label", puzzle.get("title", "")))
		button.pressed.connect(_on_hotspot_pressed.bind(hotspot, puzzle))
		hotspots.add_child(button)

		var tag := Label.new()
		tag.text = str(hotspot.get("done", "已查")) if done else str(hotspot.get("label", ""))
		tag.anchor_left = pos.x
		tag.anchor_right = pos.x
		tag.anchor_top = pos.y
		tag.anchor_bottom = pos.y
		tag.offset_left = -240
		tag.offset_right = 240
		tag.offset_top = radius + 6
		tag.offset_bottom = radius + 46
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 22)
		tag.add_theme_color_override("font_color", Color(0.88, 0.85, 0.72, 0.95) if not done else Color(0.72, 0.78, 0.62, 0.95))
		tag.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		tag.add_theme_constant_override("shadow_offset_x", 2)
		tag.add_theme_constant_override("shadow_offset_y", 2)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hotspots.add_child(tag)

		if not done:
			_pulses.append(_start_pulse(button))


func _hotspot_style(done: bool, hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.56, 0.34, 0.16 if hover else 0.06)
	if done:
		style.bg_color = Color(0.05, 0.09, 0.1, 0.5 if hover else 0.3)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.95, 0.69, 0.47, 1) if not done else Color(0.73, 0.64, 0.38, 0.8)
	style.corner_radius_top_left = 120
	style.corner_radius_top_right = 120
	style.corner_radius_bottom_left = 120
	style.corner_radius_bottom_right = 120
	style.shadow_color = Color(0.85, 0.56, 0.34, 0.4 if not done else 0.15)
	style.shadow_size = 22 if not done else 10
	return style


func _start_pulse(hotspot: Button) -> Tween:
	var tween := create_tween().set_loops()
	tween.tween_property(hotspot, "modulate:a", 0.5, 1.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(hotspot, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
	return tween


func _on_hotspot_pressed(hotspot: Dictionary, puzzle: Dictionary) -> void:
	Audio.play("paper", -7.0)
	var puzzle_id := str(puzzle.get("id", ""))
	if Chapter.is_done(puzzle_id):
		var card_id := str(puzzle.get("card", ""))
		if not card_id.is_empty():
			_open_card(Archive.get_card(card_id))
		else:
			_toast("这处已查清 · 线索在卷宗里")
		return
	var kind := str(puzzle.get("kind", ""))
	if not KIND_SCENES.has(kind):
		_toast("这类谜题尚未接入：%s" % kind)
		return
	if not Chapter.scene_unlocked(str(_scene.get("id", ""))):
		_toast("这一处还没有解锁")
		return
	GameState.current_puzzle_id = puzzle_id
	GameState.save_to()
	get_tree().change_scene_to_file(str(KIND_SCENES[kind]))


func _refresh_hint() -> void:
	_collected_cards.clear()
	var dossier := Archive.get_dossier(DOSSIER_ID)
	if dossier != null:
		for card in dossier.evidence:
			if GameState.has_evidence(card.id):
				_collected_cards.append(card)
	var remaining: Array[String] = []
	for hotspot in _scene.get("hotspots", []):
		if not Chapter.is_done(str(hotspot.get("puzzle", ""))):
			remaining.append(str(hotspot.get("label", "")))
	if remaining.is_empty():
		hint.text = "现场已清点 · 回卷宗目录继续"
	elif remaining.size() == 1:
		hint.text = tr("还有 1 处待查 ｜ %s") % tr(remaining[0])
	else:
		hint.text = tr("还有 %d 处待查 ｜ %s") % [remaining.size(), " · ".join(remaining.map(func(item: String) -> String: return tr(item)))]


func _refresh_slots() -> void:
	for child in portholes.get_children():
		portholes.remove_child(child)
		child.queue_free()
	for i in _collected_cards.size():
		var card := _collected_cards[i]
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(108, 108)
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.focus_mode = Control.FOCUS_NONE
		slot.text = SLOT_NUMERALS[i] if i < SLOT_NUMERALS.size() else str(i + 1)
		slot.add_theme_font_size_override("font_size", 26)
		slot.add_theme_color_override("font_color", Color(0.85, 0.74, 0.45, 1))
		slot.add_theme_stylebox_override("normal", _slot_style(false))
		slot.add_theme_stylebox_override("hover", _slot_style(true))
		slot.tooltip_text = card.title
		slot.pressed.connect(_open_card.bind(card))
		portholes.add_child(slot)


func _slot_style(hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.14, 0.15, 0.95) if hover else Color(0.04, 0.07, 0.08, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.74, 0.45, 0.9) if hover else Color(0.725, 0.639, 0.384, 0.55)
	style.corner_radius_top_left = 60
	style.corner_radius_top_right = 60
	style.corner_radius_bottom_left = 60
	style.corner_radius_bottom_right = 60
	return style


func _open_card(card: EvidenceCard) -> void:
	if card == null:
		return
	_card = card
	sheet_title.text = tr(card.title)
	sheet_voice.text = tr(_voice_text(card.voice))
	sheet_body.text = tr(card.body)
	sheet_source.text = tr("辑录：%s ｜ 1905 年重抄") % tr(str(_scene.get("title", "现场")))
	var cards := Archive.cards_for(DOSSIER_ID)
	var card_index := cards.find(card)
	sheet_meta.text = tr("档案 WG-1865 ｜ 卡片 %02d / %02d") % [card_index + 1, cards.size()]
	var collected := GameState.has_evidence(card.id)
	take_button.disabled = collected
	take_button.text = "已归档" if collected else "收入档案"
	sheet.visible = true
	sheet.modulate.a = 0.0
	create_tween().tween_property(sheet, "modulate:a", 1.0, 0.18)


func _close_sheet() -> void:
	sheet.visible = false
	_card = null


func _on_take_pressed() -> void:
	if _card == null or GameState.has_evidence(_card.id):
		return
	GameState.collect_evidence(_card.id, _card.weight)
	Audio.play("chime", -6.0)
	Palette.restore_with_stamp(0.06)
	GameState.save_to()
	take_button.disabled = true
	take_button.text = "已归档"
	_refresh()
	_toast("已收入档案 · 证据饱和度回升")


func _go_back() -> void:
	GameState.save_to()
	get_tree().change_scene_to_file(INDEX_PATH)


func _voice_text(voice: String) -> String:
	match voice:
		"editor":
			return "报章 · EDITOR"
		"dissent":
			return "异议 · DISSENT"
		_:
			return "物证 · EVIDENCE"


func _toast(message: String) -> void:
	toast.text = message
	toast_timer.start()


func _apply_debug_args() -> void:
	if not OS.is_debug_build():
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			GameState.current_scene_id = arg.trim_prefix("--scene=")
		elif arg == "--demo-all":
			for card_id in ["card_telegraph_1855", "card_chart_splice", "card_rayn_dissent", "card_sagar_note", "card_plate_press", "card_ledger_name", "card_plate_stack"]:
				GameState.collect_evidence(card_id, 10)
			for puzzle_id in ["P0", "P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8", "P9", "P10"]:
				Chapter.mark_done(puzzle_id)
		elif arg == "--demo-progress":
			for card_id in ["card_telegraph_1855", "card_chart_splice", "card_rayn_dissent", "card_plate_press", "card_ledger_name"]:
				GameState.collect_evidence(card_id, 10)
			for puzzle_id in ["P0", "P1", "P2", "P3", "P4", "P5"]:
				Chapter.mark_done(puzzle_id)
