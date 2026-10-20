class_name PlateToken
extends Control
## 灯下底片：可拖拽的相纸卡，松手时发 dropped，由谜题屏判定是否落在灯上。

signal dropped(token: PlateToken)

var home := Vector2.ZERO
var docked := false
var _dragging := false
var _grab_offset := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if docked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dragging = true
		_grab_offset = get_global_mouse_position() - global_position
		get_parent().move_child(self, -1)
		accept_event()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		global_position = get_global_mouse_position() - _grab_offset
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
		dropped.emit(self)
		get_viewport().set_input_as_handled()


func set_home(pos: Vector2) -> void:
	home = pos
	position = pos


func return_home() -> void:
	var tween := create_tween()
	tween.tween_property(self, "position", home, 0.24).set_trans(Tween.TRANS_SINE)


func disable_drag() -> void:
	docked = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
