class_name SaturationRect
extends TextureRect
## 现场底图的 E 调色载体，饱和度跟随 Palette。

const SATURATION_SHADER := preload("res://shaders/saturation.gdshader")

var _shader_material: ShaderMaterial


func _ready() -> void:
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = SATURATION_SHADER
	material = _shader_material
	Palette.saturation_changed.connect(_apply_saturation)
	_apply_saturation(Palette.saturation)


func _apply_saturation(value: float) -> void:
	if _shader_material != null:
		_shader_material.set_shader_parameter("saturation", value)
