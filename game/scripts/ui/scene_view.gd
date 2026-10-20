extends Control
## 现场屏：饱和度底图 + 铜环热区 + 舷窗器物栏 + 证据卡浮层。

const DOSSIER_ID := "dossier_wudu"
const SCENE_CARD_ID := "card_plate_press"
const DESK_PATH := "res://scenes/archive_desk.tscn"

@onready var ribbon_label: Label = %RibbonLabel
@onready var hotspot: Button = %Hotspot
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
var _pulse: Tween
var _collected_cards: Array[EvidenceCard] = []


func _ready() -> void:
	back_button.pressed.connect(_go_back)
	hotspot.pressed.connect(_open_scene_card)
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
	_refresh_hotspot(GameState.has_evidence(SCENE_CARD_ID))
	_refresh_slots()


func _refresh_hotspot(collected: bool) -> void:
	hotspot.disabled = collected
	hotspot.text = "已归档" if collected else ""
	if collected:
		_stop_pulse()
		hotspot.modulate.a = 1.0
		hint.text = "底片背印已收入档案"
	elif _pulse == null:
		hint.text = "点击铜环 · 查看湿版底片"
		_start_pulse()


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


func _start_pulse() -> void:
	_pulse = create_tween().set_loops()
	_pulse.tween_property(hotspot, "modulate:a", 0.5, 1.1).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(hotspot, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)


func _stop_pulse() -> void:
	if _pulse != null:
		_pulse.kill()
		_pulse = null


func _open_scene_card() -> void:
	_open_card(Archive.get_card(SCENE_CARD_ID))


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
		elif arg == "--demo-take":
			_open_scene_card()
			_on_take_pressed()
			_close_sheet()
