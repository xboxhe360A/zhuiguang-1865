extends Control
## 现场屏：饱和度底图 + 两处疑点热区 + 舷窗器物栏 + 证据卡浮层。

const DOSSIER_ID := "dossier_wudu"
const PLATE_CARD_ID := "card_plate_press"
const CHART_CARD_ID := "card_chart_splice"
const DESK_PATH := "res://scenes/archive_desk.tscn"
const DEVELOPING_PATH := "res://scenes/developing.tscn"
const LIGHT_TABLE_PATH := "res://scenes/light_table.tscn"

@onready var ribbon_label: Label = %RibbonLabel
@onready var plate_hotspot: Button = %HotspotPlate
@onready var chart_hotspot: Button = %HotspotChart
@onready var hint: Label = %Hint
@onready var portholes: HBoxContainer = %Portholes
@onready var sheet: Control = %EvidenceSheet
@onready var sheet_title: Label = %SheetTitle
@onready var sheet_voice: Label = %SheetVoice
@onready var sheet_meta: Label = %SheetMeta
@onready var sheet_body: RichTextLabel = %SheetBody
@onready var take_button: Button = %BtnTake
@onready var close_button: Button = %BtnClose
@onready var back_button: Button = %BtnBack
@onready var toast: Label = %Toast
@onready var toast_timer: Timer = %ToastTimer

var _card: EvidenceCard
var _plate_pulse: Tween
var _chart_pulse: Tween
var _collected_cards: Array[EvidenceCard] = []


func _ready() -> void:
	back_button.pressed.connect(_go_back)
	plate_hotspot.pressed.connect(_enter_developing)
	chart_hotspot.pressed.connect(_enter_light_table)
	take_button.pressed.connect(_on_take_pressed)
	close_button.pressed.connect(_close_sheet)
	toast_timer.timeout.connect(func() -> void: toast.text = "")
	for i in portholes.get_child_count():
		(portholes.get_child(i) as Button).pressed.connect(_open_slot.bind(i))
	_refresh()
	_apply_debug_args()


func _refresh() -> void:
	var dossier := Archive.get_dossier(DOSSIER_ID)
	if dossier == null:
		return

	_collected_cards.clear()
	for card in dossier.evidence:
		if GameState.has_evidence(card.id):
			_collected_cards.append(card)

	ribbon_label.text = "序卷 · 雾都    ｜    现场 · 暗房    ｜    证据 %d / %d" % [
		_collected_cards.size(),
		dossier.evidence.size(),
	]
	_refresh_hotspot(plate_hotspot, PLATE_CARD_ID, "底片背印")
	_refresh_hotspot(chart_hotspot, CHART_CARD_ID, "航图拼缝")
	_refresh_slots()
	_refresh_hint()


func _refresh_hotspot(hotspot: Button, card_id: String, card_title: String) -> void:
	var collected := GameState.has_evidence(card_id)
	hotspot.disabled = collected
	hotspot.text = "已归档" if collected else ""
	hotspot.tooltip_text = "%s · 已归档" % card_title if collected else "%s · 待查" % card_title
	if collected:
		_stop_pulse(hotspot)
		hotspot.modulate.a = 1.0
	elif hotspot == plate_hotspot:
		_plate_pulse = _start_pulse(hotspot, _plate_pulse)
	else:
		_chart_pulse = _start_pulse(hotspot, _chart_pulse)


func _refresh_hint() -> void:
	var plate_done := GameState.has_evidence(PLATE_CARD_ID)
	var chart_done := GameState.has_evidence(CHART_CARD_ID)
	if plate_done and chart_done:
		hint.text = "现场已清点 · 回到档案桌收尾"
	elif chart_done:
		hint.text = "墙上航图已校合 · 台下底片待显影"
	elif plate_done:
		hint.text = "底片已归档 · 墙上航图待校合"
	else:
		hint.text = "铜环显影底片 · 墙上航图待校合"


func _refresh_slots() -> void:
	var slots := portholes.get_children()
	for i in slots.size():
		var slot := slots[i] as Button
		if i < _collected_cards.size():
			var card := _collected_cards[i]
			slot.text = "证"
			slot.tooltip_text = card.title
			slot.disabled = false
		else:
			slot.text = ""
			slot.tooltip_text = ""
			slot.disabled = true


func _start_pulse(hotspot: Button, existing: Tween) -> Tween:
	if existing != null:
		return existing
	var tween := create_tween().set_loops()
	tween.tween_property(hotspot, "modulate:a", 0.5, 1.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(hotspot, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
	return tween


func _stop_pulse(hotspot: Button) -> void:
	var tween := _plate_pulse if hotspot == plate_hotspot else _chart_pulse
	if tween != null:
		tween.kill()
	if hotspot == plate_hotspot:
		_plate_pulse = null
	else:
		_chart_pulse = null


func _enter_developing() -> void:
	GameState.save_to()
	get_tree().change_scene_to_file(DEVELOPING_PATH)


func _enter_light_table() -> void:
	GameState.save_to()
	get_tree().change_scene_to_file(LIGHT_TABLE_PATH)


func _open_scene_card() -> void:
	_open_card(Archive.get_card(PLATE_CARD_ID))


func _open_slot(index: int) -> void:
	if index < _collected_cards.size():
		_open_card(_collected_cards[index])


func _open_card(card: EvidenceCard) -> void:
	if card == null:
		return
	_card = card
	sheet_title.text = card.title
	sheet_voice.text = _voice_text(card.voice)
	sheet_body.text = card.body
	var cards := Archive.cards_for(DOSSIER_ID)
	var card_index := cards.find(card)
	sheet_meta.text = "档案 WG-1865 ｜ 卡片 %02d / %02d" % [card_index + 1, cards.size()]
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
	Palette.restore_with_stamp(0.12)
	GameState.save_to()
	take_button.disabled = true
	take_button.text = "已归档"
	_refresh()
	_toast("已收入档案 · 证据饱和度回升")


func _go_back() -> void:
	GameState.save_to()
	get_tree().change_scene_to_file(DESK_PATH)


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
		if arg == "--demo-open":
			_open_scene_card()
		elif arg == "--demo-two":
			GameState.collect_evidence(CHART_CARD_ID, 10)
			GameState.collect_evidence(PLATE_CARD_ID, 10)
			_refresh()
