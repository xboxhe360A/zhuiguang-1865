class_name TraceSheet
extends Control
## 校图台上的描图纸：可拖动，中心十字为对位点。

signal moved(center: Vector2)
signal released(center: Vector2)

var drag_bounds := Rect2(0.0, 0.0, 1080.0, 1920.0)
var focus_ratio := Vector2(0.5, 0.5)
var _dragging := false
var _interactive := true
var _grab_offset := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func center_global() -> Vector2:
	return global_position + size * focus_ratio


func set_interactive(value: bool) -> void:
	_interactive = value
	if not value:
		_dragging = false
	mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE


func snap_center(global_center: Vector2) -> void:
	global_position = global_center - size * focus_ratio
	moved.emit(center_global())


func _gui_input(event: InputEvent) -> void:
	if not _interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dragging = true
		_grab_offset = get_global_mouse_position() - global_position
		accept_event()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		position = get_global_mouse_position() - _grab_offset
		_clamp_to_bounds()
		moved.emit(center_global())
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
		_clamp_to_bounds()
		released.emit(center_global())
		get_viewport().set_input_as_handled()


func _clamp_to_bounds() -> void:
	var min_pos := drag_bounds.position
	var max_pos := drag_bounds.end - size
	position = Vector2(
		clampf(position.x, min_pos.x, max_pos.x),
		clampf(position.y, min_pos.y, max_pos.y)
	)
