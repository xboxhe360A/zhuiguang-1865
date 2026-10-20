extends GutTest


func before_each() -> void:
	Palette.reset()


func test_saturation_clamps_to_floor() -> void:
	Palette.set_saturation(0.0)
	assert_eq(Palette.saturation, Palette.MIN_SAT)


func test_saturation_clamps_to_ceiling() -> void:
	Palette.set_saturation(2.0)
	assert_eq(Palette.saturation, Palette.MAX_SAT)


func test_same_value_does_not_emit() -> void:
	Palette.set_saturation(0.5)
	watch_signals(Palette)
	Palette.set_saturation(0.5)
	assert_signal_emit_count(Palette, "saturation_changed", 0)


func test_stamp_restores_amount() -> void:
	Palette.set_saturation(0.4)
	watch_signals(Palette)
	Palette.restore_with_stamp(0.1)
	assert_almost_eq(Palette.saturation, 0.5, 0.001)
	assert_signal_emitted_with_parameters(Palette, "saturation_changed", [0.5])


func test_stamp_cannot_exceed_ceiling() -> void:
	Palette.set_saturation(0.95)
	Palette.restore_with_stamp(0.2)
	assert_eq(Palette.saturation, Palette.MAX_SAT)
