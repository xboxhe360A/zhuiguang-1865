extends Node
## E 完整度调色盘：饱和度 = 该档证据完整度。shader 后续订阅此信号。

signal saturation_changed(value: float)

const MIN_SAT := 0.15
const MAX_SAT := 1.0

var saturation: float = 0.35


func set_saturation(value: float) -> void:
	var v := clampf(value, MIN_SAT, MAX_SAT)
	if is_equal_approx(v, saturation):
		return
	saturation = v
	saturation_changed.emit(saturation)


func add_saturation(delta: float) -> void:
	set_saturation(saturation + delta)


func restore_with_stamp(amount: float = 0.1) -> void:
	add_saturation(amount)


func reset() -> void:
	saturation = 0.35
	saturation_changed.emit(saturation)
