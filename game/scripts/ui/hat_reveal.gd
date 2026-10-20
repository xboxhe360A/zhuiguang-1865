class_name HatReveal
extends Control
## 叠片成功后的礼帽剪影：底片边缘浮出的那个「取景框外的人」。

var strength := 0.0:
	set(value):
		strength = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if strength <= 0.001:
		return
	var center := size * 0.5
	var ink := Color(0.035, 0.045, 0.055, 0.92 * strength)
	var band := Color(0.16, 0.12, 0.08, 0.9 * strength)
	var rim := Color(0.95, 0.78, 0.46, 0.55 * strength)

	var brim := PackedVector2Array()
	for i in 96:
		var angle := TAU * float(i) / 96.0
		brim.append(center + Vector2(cos(angle) * 220.0, sin(angle) * 62.0 + 54.0))
	draw_colored_polygon(brim, ink)

	var crown := PackedVector2Array()
	crown.append(center + Vector2(-122, 56))
	for i in 49:
		var angle := PI + PI * float(i) / 48.0
		crown.append(center + Vector2(cos(angle) * 122.0, sin(angle) * 158.0 + 56.0))
	crown.append(center + Vector2(122, 56))
	draw_colored_polygon(crown, ink)

	draw_rect(Rect2(center + Vector2(-124, 18), Vector2(248, 30)), band)
	draw_arc(center + Vector2(0, 54), 220.0, PI, TAU, 64, rim, 2.0, true)
