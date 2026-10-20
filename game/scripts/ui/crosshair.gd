class_name Crosshair
extends Control
## 描图纸中心十字，绘制在纸面之上。


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var center := size * 0.5
	var ink := Color(0.27, 0.14, 0.07, 0.92)
	draw_arc(center, 44.0, 0.0, TAU, 64, ink, 3.0, true)
	draw_arc(center, 30.0, 0.0, TAU, 48, Color(0.27, 0.14, 0.07, 0.35), 1.5, true)
	draw_line(center + Vector2(-76, 0), center + Vector2(-22, 0), ink, 3.0)
	draw_line(center + Vector2(22, 0), center + Vector2(76, 0), ink, 3.0)
	draw_line(center + Vector2(0, -76), center + Vector2(0, -22), ink, 3.0)
	draw_line(center + Vector2(0, 22), center + Vector2(0, 76), ink, 3.0)
	draw_circle(center, 4.0, ink)
