class_name DevelopSurface
extends Control
## 显影擦拭面：按住来回擦，按划过距离累积显影进度。

signal rubbed(amount: float)

var _rubbing := false
var _last := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func is_rubbing() -> bool:
	return _rubbing


func set_interactive(value: bool) -> void:
	_rubbing = false
	mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	set_process_input(value)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_rubbing = true
		_last = get_global_mouse_position()
		queue_redraw()
		accept_event()


func _input(event: InputEvent) -> void:
	if not _rubbing:
		return
	if event is InputEventMouseMotion:
		var now := get_global_mouse_position()
		var distance := _last.distance_to(now)
		_last = now
		if distance > 0.0:
			rubbed.emit(minf(distance * 0.00032, 0.06))
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_rubbing = false
		queue_redraw()


func _draw() -> void:
	if not _rubbing:
		return
	var p := get_local_mouse_position()
	for radius in [140.0, 100.0, 64.0]:
		draw_circle(p, radius, Color(0.95, 0.84, 0.6, 0.035))
