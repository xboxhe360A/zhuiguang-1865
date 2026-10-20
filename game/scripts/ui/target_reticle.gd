class_name TargetReticle
extends Control
## 校图目标：底图上的脉动铜环。

@export var pulse_speed := 2.2

var _phase := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := 54.0 + sin(_phase * pulse_speed) * 7.0
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.95, 0.78, 0.46, 0.9), 3.5, true)
	draw_arc(center, radius + 20.0, 0.0, TAU, 64, Color(0.95, 0.78, 0.46, 0.25), 2.0, true)
	draw_circle(center, 5.0, Color(0.95, 0.78, 0.46, 0.9))
