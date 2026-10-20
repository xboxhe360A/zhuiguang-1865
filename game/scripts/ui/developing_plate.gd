class_name DevelopingPlate
extends TextureRect
## 湿版底片：同时承载显影进度与 E 调色盘饱和度。

const DEVELOP_SHADER := preload("res://shaders/develop.gdshader")

var _material: ShaderMaterial


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = DEVELOP_SHADER
	material = _material
	Palette.saturation_changed.connect(_on_saturation_changed)
	_apply_saturation(Palette.saturation)
	set_progress(0.0)


func _exit_tree() -> void:
	if Palette.saturation_changed.is_connected(_on_saturation_changed):
		Palette.saturation_changed.disconnect(_on_saturation_changed)


func set_progress(value: float) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("progress", clampf(value, 0.0, 1.0))


func _on_saturation_changed(value: float) -> void:
	_apply_saturation(value)


func _apply_saturation(value: float) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("saturation", value)
